import { describe, it, expect, vi } from "vitest";
import request from "supertest";
import jwt from "jsonwebtoken";
import { randomUUID } from "node:crypto";

vi.mock("../config/prisma", () => {
  const garages = new Map<string, any>();
  const vehicles = new Map<string, any>();
  const garageFollowers = new Map<string, any>();
  const threads = new Map<string, any>();
  const userFollows = new Map<string, any>();
  const events = new Map<string, any>();

  return {
    prisma: {
      vehicle: {
        findMany: vi.fn(async ({ where }: any) =>
          [...vehicles.values()]
            .filter((v) => {
              if (where.isPublic !== undefined && v.isPublic !== where.isPublic) return false;
              const garage = garages.get(v.garageId);
              if (where.garage?.isPublic !== undefined && garage?.isPublic !== where.garage.isPublic) return false;
              return true;
            })
            .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
            .map((v) => ({
              ...v,
              garage: garages.get(v.garageId),
              _count: { likes: v.likeCount ?? 0, comments: v.commentCount ?? 0 },
            }))
        ),
      },
      garageFollower: {
        findMany: vi.fn(async ({ where }: any) =>
          [...garageFollowers.values()].filter(
            (f) => f.userId === where.userId && where.garageId.in.includes(f.garageId)
          )
        ),
      },
      forumThread: {
        findMany: vi.fn(async ({ where }: any) =>
          [...threads.values()]
            .filter((t) => (where.isLocked !== undefined ? t.isLocked === where.isLocked : true))
            .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime())
            .map((t) => ({
              ...t,
              author: { id: t.authorId, username: t.authorId, displayName: t.authorId },
              _count: { posts: t.postCount ?? 0 },
            }))
        ),
      },
      userFollow: {
        findMany: vi.fn(async ({ where }: any) =>
          [...userFollows.values()].filter(
            (f) => f.followerId === where.followerId && where.followingId.in.includes(f.followingId)
          )
        ),
      },
      event: {
        findMany: vi.fn(async ({ where }: any) =>
          [...events.values()]
            .filter((e) => !e.isCancelled && e.startTime >= where.startTime.gte)
            .sort((a, b) => a.startTime.getTime() - b.startTime.getTime())
            .map((e) => ({ ...e, _count: { rsvps: e.rsvpCount ?? 0 } }))
        ),
      },
      __seed: { garages, vehicles, garageFollowers, threads, userFollows, events },
    },
  };
});

vi.mock("../config/redis", () => ({
  redis: { sendCommand: vi.fn(async () => "OK"), isOpen: true, connect: vi.fn(), quit: vi.fn(), on: vi.fn() },
  connectRedis: vi.fn(async () => {}),
}));

vi.mock("../middleware/rateLimit", () => ({
  authRateLimiter: (_req: unknown, _res: unknown, next: () => void) => next(),
  apiRateLimiter: (_req: unknown, _res: unknown, next: () => void) => next(),
}));

process.env.JWT_ACCESS_SECRET = "a".repeat(32);
process.env.DATABASE_URL = "postgresql://test";
process.env.REDIS_URL = "redis://test";

const { createApp } = await import("../app");
const { prisma } = (await import("../config/prisma")) as any;

function tokenFor(userId: string) {
  return jwt.sign({ sub: userId, role: "USER" }, process.env.JWT_ACCESS_SECRET!, { expiresIn: "15m" });
}

function daysAgo(n: number) {
  return new Date(Date.now() - n * 24 * 60 * 60 * 1000);
}
function daysFromNow(n: number) {
  return new Date(Date.now() + n * 24 * 60 * 60 * 1000);
}

describe("Discover / recommendation feed", () => {
  const app = createApp();
  const viewer = tokenFor("user_viewer");

  it("works for anonymous, unauthenticated requests", async () => {
    const res = await request(app).get("/api/v1/discover");
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data)).toBe(true);
  });

  it("blends vehicles, threads, and events into one ranked list", async () => {
    const publicGarageId = randomUUID();
    prisma.__seed.garages.set(publicGarageId, { id: publicGarageId, isPublic: true, ownerId: "user_owner" });

    const highEngagementVehicleId = randomUUID();
    prisma.__seed.vehicles.set(highEngagementVehicleId, {
      id: highEngagementVehicleId,
      garageId: publicGarageId,
      isPublic: true,
      make: "Honda",
      model: "Civic Type R",
      year: 2023,
      nickname: null,
      createdAt: daysAgo(1),
      likeCount: 50,
      commentCount: 20,
    });

    const lowEngagementVehicleId = randomUUID();
    prisma.__seed.vehicles.set(lowEngagementVehicleId, {
      id: lowEngagementVehicleId,
      garageId: publicGarageId,
      isPublic: true,
      make: "Toyota",
      model: "Corolla",
      year: 2015,
      nickname: null,
      createdAt: daysAgo(20),
      likeCount: 0,
      commentCount: 0,
    });

    const threadId = randomUUID();
    prisma.__seed.threads.set(threadId, {
      id: threadId,
      categoryId: randomUUID(),
      authorId: "user_someone",
      title: "Best track day mods under $500",
      slug: "best-track-day-mods",
      isPinned: false,
      isLocked: false,
      updatedAt: daysAgo(1),
      postCount: 15,
    });

    const eventId = randomUUID();
    prisma.__seed.events.set(eventId, {
      id: eventId,
      type: "CARS_AND_COFFEE",
      title: "This Weekend's Meet",
      locationName: "Downtown",
      startTime: daysFromNow(2),
      isCancelled: false,
      rsvpCount: 30,
    });

    const res = await request(app).get("/api/v1/discover?limit=10").set("Authorization", `Bearer ${viewer}`);
    expect(res.status).toBe(200);

    const types = res.body.data.map((item: any) => item.type);
    expect(types).toContain("vehicle");
    expect(types).toContain("thread");
    expect(types).toContain("event");

    const highIndex = res.body.data.findIndex((i: any) => i.item.id === highEngagementVehicleId);
    const lowIndex = res.body.data.findIndex((i: any) => i.item.id === lowEngagementVehicleId);
    expect(highIndex).toBeGreaterThanOrEqual(0);
    expect(lowIndex).toBeGreaterThan(highIndex);
  });

  it("boosts a vehicle from a garage the viewer follows", async () => {
    const followedGarageId = randomUUID();
    const unfollowedGarageId = randomUUID();
    prisma.__seed.garages.set(followedGarageId, { id: followedGarageId, isPublic: true, ownerId: "user_a" });
    prisma.__seed.garages.set(unfollowedGarageId, { id: unfollowedGarageId, isPublic: true, ownerId: "user_b" });

    const followedVehicleId = randomUUID();
    const unfollowedVehicleId = randomUUID();
    const sharedFields = {
      make: "Mazda",
      model: "Miata",
      year: 2021,
      nickname: null,
      createdAt: daysAgo(1),
      likeCount: 5,
      commentCount: 2,
    };
    prisma.__seed.vehicles.set(followedVehicleId, {
      id: followedVehicleId,
      garageId: followedGarageId,
      isPublic: true,
      ...sharedFields,
    });
    prisma.__seed.vehicles.set(unfollowedVehicleId, {
      id: unfollowedVehicleId,
      garageId: unfollowedGarageId,
      isPublic: true,
      ...sharedFields,
    });

    prisma.__seed.garageFollowers.set(`${followedGarageId}:user_viewer`, {
      garageId: followedGarageId,
      userId: "user_viewer",
    });

    const res = await request(app).get("/api/v1/discover?limit=50").set("Authorization", `Bearer ${viewer}`);
    const followedItem = res.body.data.find((i: any) => i.item?.id === followedVehicleId);
    const unfollowedItem = res.body.data.find((i: any) => i.item?.id === unfollowedVehicleId);

    expect(followedItem.score).toBeGreaterThan(unfollowedItem.score);
  });

  it("excludes vehicles from private garages", async () => {
    const privateGarageId = randomUUID();
    prisma.__seed.garages.set(privateGarageId, { id: privateGarageId, isPublic: false, ownerId: "user_c" });

    const privateVehicleId = randomUUID();
    prisma.__seed.vehicles.set(privateVehicleId, {
      id: privateVehicleId,
      garageId: privateGarageId,
      isPublic: true,
      make: "Nissan",
      model: "GT-R",
      year: 2022,
      nickname: null,
      createdAt: daysAgo(1),
      likeCount: 100,
      commentCount: 100,
    });

    const res = await request(app).get("/api/v1/discover?limit=50");
    expect(res.body.data.some((i: any) => i.item?.id === privateVehicleId)).toBe(false);
  });

  it("excludes cancelled events", async () => {
    const cancelledEventId = randomUUID();
    prisma.__seed.events.set(cancelledEventId, {
      id: cancelledEventId,
      type: "MEETUP",
      title: "Cancelled Meet",
      locationName: "Nowhere",
      startTime: daysFromNow(3),
      isCancelled: true,
      rsvpCount: 999,
    });

    const res = await request(app).get("/api/v1/discover?limit=50");
    expect(res.body.data.some((i: any) => i.item?.id === cancelledEventId)).toBe(false);
  });

  it("respects the limit parameter", async () => {
    const res = await request(app).get("/api/v1/discover?limit=1");
    expect(res.status).toBe(200);
    expect(res.body.data.length).toBeLessThanOrEqual(1);
  });

  it("rejects a limit above the maximum", async () => {
    const res = await request(app).get("/api/v1/discover?limit=999");
    expect(res.status).toBe(400);
  });
});
