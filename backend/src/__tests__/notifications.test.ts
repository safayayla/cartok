import { describe, it, expect, vi } from "vitest";
import request from "supertest";
import jwt from "jsonwebtoken";
import { randomUUID } from "node:crypto";

vi.mock("../config/prisma", () => {
  const notifications = new Map<string, any>();

  return {
    prisma: {
      notification: {
        create: vi.fn(async ({ data }: any) => {
          const n = { id: randomUUID(), isRead: false, createdAt: new Date(), ...data };
          notifications.set(n.id, n);
          return n;
        }),
        findUnique: vi.fn(async ({ where }: any) => notifications.get(where.id) ?? null),
        findMany: vi.fn(async ({ where, take }: any) => {
          const items = [...notifications.values()]
            .filter((n) => n.recipientId === where.recipientId)
            .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
          return take ? items.slice(0, take) : items;
        }),
        count: vi.fn(async ({ where }: any) =>
          [...notifications.values()].filter((n) => n.recipientId === where.recipientId && !n.isRead).length
        ),
        update: vi.fn(async ({ where, data }: any) => {
          const n = notifications.get(where.id);
          Object.assign(n, data);
          return n;
        }),
        updateMany: vi.fn(async ({ where, data }: any) => {
          let count = 0;
          for (const n of notifications.values()) {
            if (n.recipientId === where.recipientId && !n.isRead) {
              Object.assign(n, data);
              count += 1;
            }
          }
          return { count };
        }),
      },
      // Seed helper used directly by the test below.
      __seed: notifications,
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

describe("Notifications module", () => {
  const app = createApp();
  const carol = tokenFor("user_carol");
  const dave = tokenFor("user_dave");

  it("lists notifications only for the authenticated recipient", async () => {
    const idForCarol = randomUUID();
    prisma.__seed.set(idForCarol, {
      id: idForCarol,
      recipientId: "user_carol",
      actorId: "user_dave",
      type: "GARAGE_FOLLOW",
      message: "started following your garage",
      isRead: false,
      createdAt: new Date(),
    });
    const idForDave = randomUUID();
    prisma.__seed.set(idForDave, {
      id: idForDave,
      recipientId: "user_dave",
      actorId: "user_carol",
      type: "GARAGE_FOLLOW",
      message: "started following your garage",
      isRead: false,
      createdAt: new Date(),
    });

    const res = await request(app).get("/api/v1/notifications").set("Authorization", `Bearer ${carol}`);
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].recipientId).toBe("user_carol");
  });

  it("reports the correct unread count", async () => {
    const res = await request(app)
      .get("/api/v1/notifications/unread-count")
      .set("Authorization", `Bearer ${carol}`);
    expect(res.status).toBe(200);
    expect(res.body.data.count).toBe(1);
  });

  it("prevents marking someone else's notification as read", async () => {
    const list = await request(app).get("/api/v1/notifications").set("Authorization", `Bearer ${dave}`);
    const notificationId = list.body.data[0].id;

    const res = await request(app)
      .post(`/api/v1/notifications/${notificationId}/read`)
      .set("Authorization", `Bearer ${carol}`); // Carol trying to mark Dave's notification
    expect(res.status).toBe(403);
  });

  it("marks all of the caller's notifications as read", async () => {
    await request(app).post("/api/v1/notifications/read-all").set("Authorization", `Bearer ${carol}`);

    const res = await request(app)
      .get("/api/v1/notifications/unread-count")
      .set("Authorization", `Bearer ${carol}`);
    expect(res.body.data.count).toBe(0);
  });

  it("requires authentication", async () => {
    const res = await request(app).get("/api/v1/notifications");
    expect(res.status).toBe(401);
  });
});
