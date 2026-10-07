import { prisma } from "../../config/prisma";

/**
 * A real, working recommendation feed — but an honest one. This is a
 * heuristic ranking (engagement + recency + "do you follow the source"),
 * not a machine-learned model. There's no video content — that was an
 * earlier product direction that's since been dropped (see
 * ARCHITECTURE.md) — so this surfaces the content types that do exist:
 * public vehicles, forum threads, and upcoming events.
 *
 * Known limitations, documented rather than hidden:
 *  - Each type's score is computed independently with different weights
 *    and is NOT normalized onto a shared scale before blending. A very
 *    engaged thread can currently outrank every vehicle, or vice versa.
 *    Proper cross-type normalization (e.g. z-score per type before
 *    merging) is real future work, not done here.
 *  - This queries a bounded recent/candidate pool per type and scores it
 *    in application code, rather than a single ranked SQL query or a
 *    precomputed feature store. That's fine at today's data volume; a
 *    production system serving millions of users would batch-score
 *    candidates offline rather than rank live on every request.
 */

const CANDIDATE_POOL_SIZE = 40;
const RECENCY_WINDOW_DAYS = 14;
const FOLLOW_BOOST = 10;

function recencyBoost(date: Date): number {
  const daysSince = (Date.now() - date.getTime()) / (1000 * 60 * 60 * 24);
  return Math.max(0, RECENCY_WINDOW_DAYS - daysSince);
}

export const discoverService = {
  async getFeed(viewerId: string | undefined, limit: number) {
    const [vehicleItems, threadItems, eventItems] = await Promise.all([
      this.scoreVehicles(viewerId),
      this.scoreThreads(viewerId),
      this.scoreEvents(),
    ]);

    const blended = [...vehicleItems, ...threadItems, ...eventItems].sort((a, b) => b.score - a.score);

    return blended.slice(0, limit);
  },

  async scoreVehicles(viewerId?: string) {
    const vehicles = await prisma.vehicle.findMany({
      where: { isPublic: true, garage: { isPublic: true } },
      orderBy: { createdAt: "desc" },
      take: CANDIDATE_POOL_SIZE,
      include: {
        garage: { select: { id: true, name: true, ownerId: true } },
        _count: { select: { likes: true, comments: true } },
      },
    });

    const followedGarageIds = viewerId
      ? new Set(
          (
            await prisma.garageFollower.findMany({
              where: { userId: viewerId, garageId: { in: vehicles.map((v: { garageId: string }) => v.garageId) } },
              select: { garageId: true },
            })
          ).map((f: { garageId: string }) => f.garageId)
        )
      : new Set<string>();

    return vehicles.map((v: { id: string; garageId: string; createdAt: Date; make: string; model: string; year: number; nickname: string | null; garage: unknown; _count: { likes: number; comments: number } }) => ({
      type: "vehicle" as const,
      score:
        v._count.likes * 2 +
        v._count.comments * 3 +
        recencyBoost(v.createdAt) +
        (followedGarageIds.has(v.garageId) ? FOLLOW_BOOST : 0),
      item: {
        id: v.id,
        garageId: v.garageId,
        make: v.make,
        model: v.model,
        year: v.year,
        nickname: v.nickname,
        likeCount: v._count.likes,
        commentCount: v._count.comments,
        garage: v.garage,
      },
    }));
  },

  async scoreThreads(viewerId?: string) {
    const threads = await prisma.forumThread.findMany({
      where: { isLocked: false },
      orderBy: { updatedAt: "desc" },
      take: CANDIDATE_POOL_SIZE,
      include: {
        author: { select: { id: true, username: true, displayName: true } },
        _count: { select: { posts: true } },
      },
    });

    const followedAuthorIds = viewerId
      ? new Set(
          (
            await prisma.userFollow.findMany({
              where: { followerId: viewerId, followingId: { in: threads.map((t: { authorId: string }) => t.authorId) } },
              select: { followingId: true },
            })
          ).map((f: { followingId: string }) => f.followingId)
        )
      : new Set<string>();

    return threads.map((t: {
      id: string;
      categoryId: string;
      title: string;
      authorId: string;
      isPinned: boolean;
      updatedAt: Date;
      author: unknown;
      _count: { posts: number };
    }) => ({
      type: "thread" as const,
      score:
        t._count.posts * 2 +
        recencyBoost(t.updatedAt) +
        (t.isPinned ? FOLLOW_BOOST : 0) +
        (followedAuthorIds.has(t.authorId) ? FOLLOW_BOOST : 0),
      item: {
        id: t.id,
        categoryId: t.categoryId,
        title: t.title,
        postCount: t._count.posts,
        author: t.author,
      },
    }));
  },

  async scoreEvents() {
    const events = await prisma.event.findMany({
      where: { isCancelled: false, startTime: { gte: new Date() } },
      orderBy: { startTime: "asc" },
      take: CANDIDATE_POOL_SIZE,
      include: { _count: { select: { rsvps: true } } },
    });

    return events.map((e: {
      id: string;
      type: string;
      title: string;
      locationName: string;
      startTime: Date;
      _count: { rsvps: number };
    }) => {
      const daysUntil = Math.max(0, (e.startTime.getTime() - Date.now()) / (1000 * 60 * 60 * 24));
      // Sooner events score higher, but only within a ~2 week horizon —
      // an event 6 months out shouldn't dominate the feed just for existing.
      const proximityBoost = Math.max(0, 14 - daysUntil);
      return {
        type: "event" as const,
        score: e._count.rsvps * 3 + proximityBoost,
        item: {
          id: e.id,
          type: e.type,
          title: e.title,
          locationName: e.locationName,
          startTime: e.startTime,
          rsvpCount: e._count.rsvps,
        },
      };
    });
  },
};
