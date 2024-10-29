import axios from 'axios';
import { Friend, Group } from '@icqqjs/icqq';
import * as https from 'node:https';

export function getAvatarUrl(room: number | bigint | Friend | Group): string {
  if (!room) return '';
  if (room instanceof Friend) {
    room = room.user_id;
  }
  if (room instanceof Group) {
    room = -room.group_id;
  }
  return room < 0 ?
    `https://p.qlogo.cn/gh/${-room}/${-room}/0` :
    `https://q1.qlogo.cn/g?b=qq&nk=${room}&s=0`;
}

export function getImageUrlByMd5(md5: string) {
  return 'https://gchat.qpic.cn/gchatpic_new/0/0-0-' + md5.toUpperCase() + '/0';
}

export function getBigFaceUrl(file: string) {
  return `https://gxh.vip.qq.com/club/item/parcel/item/${file.substring(0, 2)}/${file.substring(0, 32)}/300x300.png`;
}

const httpsAgent = new https.Agent({
  rejectUnauthorized: false,
});

export async function fetchFile(url: string): Promise<Buffer> {
  const res = await axios.get(url, {
    responseType: 'arraybuffer',
    httpsAgent,
  });
  return res.data;
}

export function getAvatar(room: number | Friend | Group) {
  return fetchFile(getAvatarUrl(room));
}

export function isContainsUrl(msg: string): boolean {
  return msg.includes('https://') || msg.includes('http://');
}
