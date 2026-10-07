import { describe, it, expect, vi } from "vitest";
import request from "supertest";
import jwt from "jsonwebtoken";
import { randomUUID } from "node:crypto";

vi.mock("../config/prisma", () => {
  const users = new Map<string, any>();
  const follows = new Map<string, any>();
  const notifications = new Map<string, any>();
  const nextId = () => randomUUID();

  function seedUser(id: string, username: string) {
    const user = {
      id,
      username,
      displayName: username,
      email: `${username}@example.com`,
      bio: null,
      avatarUrl: null,
      verification: "UNVERIFIED",
      role: "USER",
      isActive: true,
      isBanned: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    users.set(id, user);
    return user;
  }

  seedUser("user_alice", "alice");
  seedUser("user_bob", "bob");
  seedUser("user_carol", "carol");

  return {
    prisma: {
      user: {
        findUnique: vi.fn(async ({ where }: any) => {
          if (where.id) return users.get(where.id) ?? null;
          if (where.username) return [...users.values()].find((u) => u.username === where.username) ?? null;
          return null;
        }),
        findMany: vi.fn(async ({ where, take }: any) => {
          const term = where.OR[0].username.contains.toLowerCase();
          const matches = [...users.values()]
            .filter((u) => !u.isBanned)
            .filter((u) => u.username.toLowerCase().includes(term) || u.displayName.toLowerCase().includes(term))
            .sort((a, b) => a.username.localeCompare(b.username))
            .map((u) => ({
              id: u.id,
              username: u.username,
              displayName: u.displayName,
              avatarUrl: u.avatarUrl,
              verification: u.verification,
            }));
          return take ? matches.slice(0, take) : matches;
        }),
        update: vi.fn(async ({ where, data }: any) => {
          const user = users.get(where.id);
          Object.assign(user, data);
          return user;
        }),
      },
      userFollow: {
        upsert: vi.fn(async ({ where, create }: any) => {
          const key = `${where.followerId_followingId.followerId}:${where.followerId_followingId.followingId}`;
          const follow = follows.get(key) ?? { id: nextId(), createdAt: new Date(), ...create };
          follows.set(key, follow);
          return follow;
        }),
        deleteMany: vi.fn(async ({ where }: any) => {
          follows.delete(`${where.followerId}:${where.followingId}`);
          return { count: 1 };
        }),
        findUnique: vi.fn(async ({ where }: any) => {
          const key = `${where.followerId_followingId.followerId}:${where.followerId_followingId.followingId}`;
          return follows.get(key) ?? null;
        }),
        count: vi.fn(async ({ where }: any) =>
          [...follows.values()].filter((f) =>
            where.followingId ? f.followingId === where.followingId : f.followerId === where.followerId
          ).length
        ),
        findMany: vi.fn(async ({ where }: any) =>
          [...follows.values()]
            .filter((f) => (where.followingId ? f.followingId === where.followingId : f.followerId === where.followerId))
            .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
            .map((f) => ({
              ...f,
              follower: users.get(f.followerId),
              following: users.get(f.followingId),
            }))
        ),
      },
      notification: {
        create: vi.fn(async ({ data }: any) => {
          const n = { id: nextId(), isRead: false, createdAt: new Date(), ...data };
          notifications.set(n.id, n);
          return n;
        }),
        findMany: vi.fn(async ({ where }: any) =>
          [...notifications.values()].filter((n) => n.recipientId === where.recipientId)
        ),
      },
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

function tokenFor(userId: string) {
  return jwt.sign({ sub: userId, role: "USER" }, process.env.JWT_ACCESS_SECRET!, { expiresIn: "15m" });
}

describe("Users module — profiles and follow system", () => {
  const app = createApp();
  const alice = tokenFor("user_alice");
  const bob = tokenFor("user_bob");

  it("fetches a public profile anonymously with zero follow counts", async () => {
    const res = await request(app).get("/api/v1/users/carol");
    expect(res.status).toBe(200);
    expect(res.body.data.username).toBe("carol");
    expect(res.body.data.followerCount).toBe(0);
    expect(res.body.data.isFollowedByMe).toBe(false);
    expect(res.body.data.email).toBeUndefined();
  });

  it("returns 404 for an unknown username", async () => {
    const res = await request(app).get("/api/v1/users/nobody");
    expect(res.status).toBe(404);
  });

  it("requires auth to follow", async () => {
    const res = await request(app).post("/api/v1/users/bob/follow");
    expect(res.status).toBe(401);
  });

  it("rejects following yourself", async () => {
    const res = await request(app).post("/api/v1/users/alice/follow").set("Authorization", `Bearer ${alice}`);
    expect(res.status).toBe(400);
  });

  it("lets alice follow bob and updates counts + isFollowedByMe", async () => {
    const followRes = await request(app)
      .post("/api/v1/users/bob/follow")
      .set("Authorization", `Bearer ${alice}`);
    expect(followRes.status).toBe(204);

    const bobProfile = await request(app).get("/api/v1/users/bob").set("Authorization", `Bearer ${alice}`);
    expect(bobProfile.body.data.followerCount).toBe(1);
    expect(bobProfile.body.data.isFollowedByMe).toBe(true);

    const aliceProfile = await request(app).get("/api/v1/users/alice").set("Authorization", `Bearer ${alice}`);
    expect(aliceProfile.body.data.followingCount).toBe(1);
  });

  it("notifies bob when followed", async () => {
    const notifRes = await request(app).get("/api/v1/notifications").set("Authorization", `Bearer ${bob}`);
    expect(notifRes.body.data.some((n: any) => n.type === "USER_FOLLOW")).toBe(true);
  });

  it("is idempotent - following twice does not double-count", async () => {
    await request(app).post("/api/v1/users/bob/follow").set("Authorization", `Bearer ${alice}`);
    const bobProfile = await request(app).get("/api/v1/users/bob");
    expect(bobProfile.body.data.followerCount).toBe(1);
  });

  it("lists bob's followers, including alice", async () => {
    const res = await request(app).get("/api/v1/users/bob/followers");
    expect(res.status).toBe(200);
    expect(res.body.data.some((u: any) => u.username === "alice")).toBe(true);
  });

  it("lists alice's following, including bob", async () => {
    const res = await request(app).get("/api/v1/users/alice/following");
    expect(res.status).toBe(200);
    expect(res.body.data.some((u: any) => u.username === "bob")).toBe(true);
  });

  it("unfollows and reflects it immediately", async () => {
    const unfollowRes = await request(app)
      .delete("/api/v1/users/bob/follow")
      .set("Authorization", `Bearer ${alice}`);
    expect(unfollowRes.status).toBe(204);

    const bobProfile = await request(app).get("/api/v1/users/bob").set("Authorization", `Bearer ${alice}`);
    expect(bobProfile.body.data.followerCount).toBe(0);
    expect(bobProfile.body.data.isFollowedByMe).toBe(false);
  });

  it("updates the authenticated user's own profile", async () => {
    const res = await request(app)
      .patch("/api/v1/users/me")
      .set("Authorization", `Bearer ${alice}`)
      .send({ bio: "Track day enthusiast" });
    expect(res.status).toBe(200);
    expect(res.body.data.bio).toBe("Track day enthusiast");
    expect(res.body.data.passwordHash).toBeUndefined();
  });

  it("searches users by username without requiring auth", async () => {
    const res = await request(app).get("/api/v1/users/search?q=ali");
    expect(res.status).toBe(200);
    expect(res.body.data.some((u: any) => u.username === "alice")).toBe(true);
  });

  it("never leaks passwordHash or email through search results", async () => {
    const res = await request(app).get("/api/v1/users/search?q=alice");
    expect(res.body.data[0].passwordHash).toBeUndefined();
    expect(res.body.data[0].email).toBeUndefined();
  });

  it("routes 'search' to the search endpoint rather than treating it as a username", async () => {
    // Regression guard: /search must be registered before /:username or
    // this request would 404 as "no user named 'search'" instead of
    // hitting the search handler.
    const res = await request(app).get("/api/v1/users/search?q=bob");
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data)).toBe(true);
  });

  it("requires a non-empty query", async () => {
    const res = await request(app).get("/api/v1/users/search?q=");
    expect(res.status).toBe(400);
  });
});
