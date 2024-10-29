# syntax=docker/dockerfile:labs

FROM ghcr.io/linuxserver/baseimage:latest AS base
LABEL maintainer="your-name"

# 基础镜像设置
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
WORKDIR /app

# 使用 base 镜像，安装通用依赖和工具
RUN apk add --no-cache \
    fonts-wqy-microhei \
    gosu \
    libpixman \
    libcairo \
    libpango \
    libgif \
    libjpeg-turbo \
    libpng \
    librsvg \
    libvips \
    ffmpeg \
    librlottie \
    && corepack enable

# 构建阶段1：安装编译依赖和应用依赖
FROM base AS build
RUN apk add --no-cache \
    python3 \
    build-base \
    pkgconfig \
    libcairo-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    librsvg-dev \
    libvips-dev

COPY pnpm-workspace.yaml package.json pnpm-lock.yaml .npmrc /app/
COPY patches /app/patches
COPY main/package.json /app/main/
RUN --mount=type=cache,id=pnpm,target=/pnpm/store,sharing=locked \
    pnpm install --frozen-lockfile

COPY main/tsconfig.json main/build.ts /app/main/
COPY main/prisma /app/main/prisma
COPY main/src /app/main/src
RUN cd main && pnpm exec prisma generate && pnpm run build

# 构建阶段2：安装并构建 tgs-to-gif
FROM debian:bookworm-slim AS tgs-to-gif-build
RUN apt update && apt-get install -y --no-install-recommends \
    python3 \
    build-essential \
    cmake \
    librlottie-dev \
    zlib1g-dev

ADD https://github.com/p-ranav/argparse.git#v3.0 /argparse
WORKDIR /argparse/build
RUN cmake -DARGPARSE_BUILD_SAMPLES=off -DARGPARSE_BUILD_TESTS=off .. && make && make install

ADD https://github.com/ed-asriyan/lottie-converter.git#f626548ced4492235b535552e2449be004a3a435 /app
WORKDIR /app
RUN sed -i 's/\${CONAN_LIBS}/z/g' CMakeLists.txt && \
    sed -i 's/include(conanbuildinfo.cmake)//g' CMakeLists.txt && \
    sed -i 's/conan_basic_setup()//g' CMakeLists.txt && \
    cmake CMakeLists.txt && make

# 构建阶段3：前端构建
FROM base AS build-front
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml /app/
COPY patches /app/patches
COPY ui/ /app/ui/
RUN --mount=type=cache,id=pnpm,target=/pnpm/store,sharing=locked \
    pnpm install --frozen-lockfile
RUN cd ui && pnpm run build

# 最终镜像
FROM base
COPY --from=tgs-to-gif-build /app/tgs_to_gif /usr/local/bin/tgs_to_gif
ENV TGS_TO_GIF=/usr/local/bin/tgs_to_gif

COPY --from=build /app/deploy /app
COPY main/prisma /app/
RUN pnpm exec prisma generate

COPY --from=build-front /app/ui/dist /app/front
ENV UI_PATH=/app/front

COPY docker-entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENV DATA_DIR=/app/data
ENV CACHE_DIR=/app/.config/QQ/NapCat/temp

ARG REPO
ARG REF
ARG COMMIT
ENV REPO $REPO
ENV REF $REF
ENV COMMIT $COMMIT

EXPOSE 8080
CMD ["/app/entrypoint.sh"]
