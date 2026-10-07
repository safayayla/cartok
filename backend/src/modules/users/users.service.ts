import { prisma } from "../../config/prisma";
import { Errors } from "../../middleware/errors";
import { notificationsService } from "../notifications/notifications.service";

export const usersService = {
  async getById(id: string) {
    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) throw Errors.notFound("User not found");
    return user;
  },

  async getByUsername(username: string, viewerId?: string) {
    const user = await prisma.user.findUnique({ where: { username } });
    if (!user) throw Errors.notFound("User not found");

    const [followerCount, followingCount, isFollowedByMe] = await Promise.all([
      prisma.userFollow.count({ where: { followingId: user.id } }),
      prisma.userFollow.count({ where: { followerId: user.id } }),
      viewerId && viewerId !== user.id
        ? prisma.userFollow.findUnique({
            where: { followerId_followingId: { followerId: viewerId, followingId: user.id } },
          })
        : null,
    ]);

    return { user, followerCount, followingCount, isFollowedByMe: Boolean(isFollowedByMe) };
  },

  async search(query: string, limit: number) {
    const users = await prisma.user.findMany({
      where: {
        isBanned: false,
        OR: [
          { username: { contains: query, mode: "insensitive" } },
          { displayName: { contains: query, mode: "insensitive" } },
        ],
      },
      take: limit,
      orderBy: { username: "asc" },
      select: { id: true, username: true, displayName: true, avatarUrl: true, verification: true },
    });
    return users;
  },

  async updateProfile(id: string, data: { displayName?: string; bio?: string; avatarUrl?: string }) {
    return prisma.user.update({ where: { id }, data });
  },

  async follow(followerId: string, targetUsername: string) {
    const target = await prisma.user.findUnique({ where: { username: targetUsername } });
    if (!target) throw Errors.notFound("User not found");
    if (target.id === followerId) throw Errors.badRequest("You can't follow yourself");

    await prisma.userFollow.upsert({
      where: { followerId_followingId: { followerId, followingId: target.id } },
      create: { followerId, followingId: target.id },
      update: {},
    });

    await notificationsService.emit({
      recipientId: target.id,
      actorId: followerId,
      type: "USER_FOLLOW",
      message: "started following you",
      entityType: "User",
      entityId: followerId,
    });
  },

  async unfollow(followerId: string, targetUsername: string) {
    const target = await prisma.user.findUnique({ where: { username: targetUsername } });
    if (!target) throw Errors.notFound("User not found");

    await prisma.userFollow.deleteMany({ where: { followerId, followingId: target.id } });
  },

  async listFollowers(targetUsername: string, { cursor, limit = 20 }: { cursor?: string; limit?: number }) {
    const target = await prisma.user.findUnique({ where: { username: targetUsername }, select: { id: true } });
    if (!target) throw Errors.notFound("User not found");

    const rows = await prisma.userFollow.findMany({
      where: { followingId: target.id },
      orderBy: { createdAt: "desc" },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: {
        follower: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
      },
    });

    const hasMore = rows.length > limit;
    const page = hasMore ? rows.slice(0, limit) : rows;
    return {
      items: page.map((r: { follower: unknown }) => r.follower),
      nextCursor: hasMore ? page[page.length - 1].id : null,
    };
  },

  async listFollowing(targetUsername: string, { cursor, limit = 20 }: { cursor?: string; limit?: number }) {
    const target = await prisma.user.findUnique({ where: { username: targetUsername }, select: { id: true } });
    if (!target) throw Errors.notFound("User not found");

    const rows = await prisma.userFollow.findMany({
      where: { followerId: target.id },
      orderBy: { createdAt: "desc" },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: {
        following: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
      },
    });

    const hasMore = rows.length > limit;
    const page = hasMore ? rows.slice(0, limit) : rows;
    return {
      items: page.map((r: { following: unknown }) => r.following),
      nextCursor: hasMore ? page[page.length - 1].id : null,
    };
  },
};
