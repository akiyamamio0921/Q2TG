import { FastifyPluginCallback } from 'fastify';
import { Pair } from '../models/Pair';
import ejs from 'ejs';
import fs from 'fs';
import { Group } from '@icqqjs/icqq';
import { format } from 'date-and-time';

const template = ejs.compile(fs.readFileSync('./assets/richHeader.ejs', 'utf-8'));

export default ((fastify, opts, done) => {
  fastify.get<{
    Params: { apiKey: string, userId: string }
  }>('/:apiKey/:userId', async (request, reply) => {
    const pair = Pair.getByApiKey(request.params.apiKey);
    if (!pair) {
      reply.code(404);
      return 'Group not found';
    }
    const group = pair.qq as Group;
    const members = await group.getMemberMap();
    const member = members.get(Number(request.params.userId));
    if (!member) {
      reply.code(404);
      return 'Member not found';
    }
    const profile = await pair.qq.client.getProfile(member.user_id);

    reply.type('text/html');
    return template({
      userId: request.params.userId,
      title: member.title,
      name: member.card || member.nickname,
      role: member.role,
      joinTime: format(new Date(member.join_time * 1000), 'YYYY-MM-DD HH:mm'),
      lastSentTime: format(new Date(member.last_sent_time * 1000), 'YYYY-MM-DD HH:mm'),
      regTime: format(new Date(profile.regTimestamp * 1000), 'YYYY-MM-DD HH:mm'),
      location: [profile.country, profile.province, profile.city].join(' ').trim(),
      nickname: member.nickname,
      email: profile.email,
      qid: profile.QID,
      signature: profile.signature,
      birthday: (profile.birthday || []).join('/'),
    });
  });

  done();
}) as FastifyPluginCallback;
