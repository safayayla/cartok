import { describe, it, expect, vi } from "vitest";
import request from "supertest";
import jwt from "jsonwebtoken";
import { randomUUID } from "node:crypto";

vi.mock("../config/prisma", () => {
  const events = new Map<string, any>();
  const rsvps = new Map<string, any>();
  const checkIns = new Map<string, any>();
  const notifications = new Map<string, any>();
  const nextId = () => randomUUID();

  const eventDelegate = {
    create: vi.fn(async ({ data }: any) => {
      const event = { id: nextId(), isCancelled: false, createdAt: new Date(), updatedAt: new Date(), ...data };
      events.set(event.id, event);
      return event;
    }),
    findUnique: vi.fn(async ({ where, include }: any) => {
      const event = where.id ? events.get(where.id) : [...events.values()].find((e) => e.checkInCode === where.checkInCode);
      if (!event) return null;
      if (include?.host) {
        return {
          ...event,
          host: { id: event.hostId, username: event.hostId, displayName: event.hostId, avatarUrl: null },
          _count: {
            rsvps: [...rsvps.values()].filter((r) => r.eventId === event.id).length,
            checkIns: [...checkIns.values()].filter((c) => c.eventId === event.id).length,
          },
        };
      }
      return event;
    }),
    findMany: vi.fn(async ({ where }: any) =>
      [...events.values()]
        .filter((e) => !e.isCancelled && e.startTime >= where.startTime.gte)
        .filter((e) => !where.type || e.type === where.type)
        .sort((a, b) => a.startTime.getTime() - b.startTime.getTime())
        .map((e) => {
          // Mirror the real select clause in events.service.ts#list, which
          // deliberately omits checkInCode from this public endpoint.
          const { checkInCode: _checkInCode, ...publicFields } = e;
          return { ...publicFields, _count: { rsvps: [...rsvps.values()].filter((r) => r.eventId === e.id).length } };
        })
    ),
    update: vi.fn(async ({ where, data }: any) => {
      const event = events.get(where.id);
      Object.assign(event, data);
      return event;
    }),
  };

  const eventRsvpDelegate = {
    findUnique: vi.fn(async ({ where }: any) => {
      const key = `${where.eventId_userId.eventId}:${where.eventId_userId.userId}`;
      return rsvps.get(key) ?? null;
    }),
    count: vi.fn(async ({ where }: any) =>
      [...rsvps.values()].filter((r) => r.eventId === where.eventId && r.status === where.status).length
    ),
    upsert: vi.fn(async ({ where, create, update }: any) => {
      const key = `${where.eventId_userId.eventId}:${where.eventId_userId.userId}`;
      const existing = rsvps.get(key);
      const rsvp = existing ? Object.assign(existing, update) : { id: nextId(), createdAt: new Date(), ...create };
      rsvps.set(key, rsvp);
      return rsvp;
    }),
    findMany: vi.fn(async ({ where }: any) =>
      [...rsvps.values()]
        .filter((r) => {
          if (r.eventId !== where.eventId) return false;
          if (where.status?.in) return where.status.in.includes(r.status);
          if (where.status) return r.status === where.status;
          return true;
        })
        .map((r) => ({ ...r, user: { id: r.userId, username: r.userId, displayName: r.userId, avatarUrl: null } }))
    ),
  };

  const eventCheckInDelegate = {
    upsert: vi.fn(async ({ where, create }: any) => {
      const key = `${where.eventId_userId.eventId}:${where.eventId_userId.userId}`;
      const existing = checkIns.get(key);
      const checkIn = existing ?? { id: nextId(), createdAt: new Date(), ...create };
      checkIns.set(key, checkIn);
      return checkIn;
    }),
  };

  return {
    prisma: {
      event: eventDelegate,
      eventRsvp: eventRsvpDelegate,
      eventCheckIn: eventCheckInDelegate,
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
      $transaction: vi.fn(async (fn: any) => {
        const tx = { eventRsvp: eventRsvpDelegate, $queryRaw: vi.fn(async () => []) };
        return fn(tx);
      }),
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

function inDays(days: number) {
  return new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString();
}

describe("Events module", () => {
  const app = createApp();
  const host = tokenFor("user_host");
  const attendee1 = tokenFor("user_attendee1");
  const attendee2 = tokenFor("user_attendee2");
  const stranger = tokenFor("user_stranger");
  let eventId: string;

  it("rejects an event with a start time in the past", async () => {
    const res = await request(app)
      .post("/api/v1/events")
      .set("Authorization", `Bearer ${host}`)
      .send({
        type: "CARS_AND_COFFEE",
        title: "Yesterday's meet",
        locationName: "Some parking lot",
        startTime: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(),
      });
    expect(res.status).toBe(400);
  });

  it("creates a Cars & Coffee event with a capacity of 1", async () => {
    const res = await request(app)
      .post("/api/v1/events")
      .set("Authorization", `Bearer ${host}`)
      .send({
        type: "CARS_AND_COFFEE",
        title: "Saturday Cars & Coffee",
        locationName: "Downtown parking structure",
        startTime: inDays(3),
        capacity: 1,
      });
    expect(res.status).toBe(201);
    expect(res.body.data.checkInCode).toBeTruthy();
    eventId = res.body.data.id;
  });

  it("lists upcoming events publicly, no auth required", async () => {
    const res = await request(app).get("/api/v1/events");
    expect(res.status).toBe(200);
    expect(res.body.data.some((e: any) => e.id === eventId)).toBe(true);
  });

  it("lets the first attendee RSVP going", async () => {
    const res = await request(app)
      .post(`/api/v1/events/${eventId}/rsvp`)
      .set("Authorization", `Bearer ${attendee1}`)
      .send({ status: "GOING" });
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe("GOING");
  });

  it("rejects a second attendee once the event is at capacity", async () => {
    const res = await request(app)
      .post(`/api/v1/events/${eventId}/rsvp`)
      .set("Authorization", `Bearer ${attendee2}`)
      .send({ status: "GOING" });
    expect(res.status).toBe(409);
  });

  it("still allows an INTERESTED rsvp once at capacity", async () => {
    const res = await request(app)
      .post(`/api/v1/events/${eventId}/rsvp`)
      .set("Authorization", `Bearer ${attendee2}`)
      .send({ status: "INTERESTED" });
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe("INTERESTED");
  });

  it("allows the already-going attendee to re-submit GOING without hitting the capacity error", async () => {
    const res = await request(app)
      .post(`/api/v1/events/${eventId}/rsvp`)
      .set("Authorization", `Bearer ${attendee1}`)
      .send({ status: "GOING" });
    expect(res.status).toBe(200);
  });

  it("prevents a non-host from updating the event", async () => {
    const res = await request(app)
      .patch(`/api/v1/events/${eventId}`)
      .set("Authorization", `Bearer ${stranger}`)
      .send({ title: "Hijacked" });
    expect(res.status).toBe(403);
  });

  it("rejects check-in before the check-in window opens", async () => {
    // Only the host can see the check-in code in the response now (see the
    // security fix in events.service.ts) — fetching anonymously here would
    // correctly get an undefined code, which isn't what this test is about.
    const eventRes = await request(app)
      .get(`/api/v1/events/${eventId}`)
      .set("Authorization", `Bearer ${host}`);
    const checkInCode = eventRes.body.data.checkInCode;

    const res = await request(app)
      .post(`/api/v1/events/check-in/${checkInCode}`)
      .set("Authorization", `Bearer ${attendee1}`);
    // Event starts in 3 days; the check-in window only opens 60 minutes
    // before start, so this must be rejected now.
    expect(res.status).toBe(403);
  });

  it("never exposes the check-in code to a non-host viewer", async () => {
    const anonRes = await request(app).get(`/api/v1/events/${eventId}`);
    expect(anonRes.body.data.checkInCode).toBeUndefined();

    const strangerRes = await request(app)
      .get(`/api/v1/events/${eventId}`)
      .set("Authorization", `Bearer ${stranger}`);
    expect(strangerRes.body.data.checkInCode).toBeUndefined();

    const listRes = await request(app).get("/api/v1/events");
    expect(listRes.body.data.every((e: any) => e.checkInCode === undefined)).toBe(true);

    const hostRes = await request(app)
      .get(`/api/v1/events/${eventId}`)
      .set("Authorization", `Bearer ${host}`);
    expect(hostRes.body.data.checkInCode).toBeTruthy();
  });

  it("rejects an unknown check-in code", async () => {
    const res = await request(app)
      .post(`/api/v1/events/check-in/${"0".repeat(32)}`)
      .set("Authorization", `Bearer ${attendee1}`);
    expect(res.status).toBe(404);
  });

  it("cancels the event as host and notifies attendees", async () => {
    const res = await request(app)
      .post(`/api/v1/events/${eventId}/cancel`)
      .set("Authorization", `Bearer ${host}`);
    expect(res.status).toBe(200);
    expect(res.body.data.isCancelled).toBe(true);

    const notifRes = await request(app)
      .get("/api/v1/notifications")
      .set("Authorization", `Bearer ${attendee1}`);
    expect(notifRes.body.data.some((n: any) => n.type === "EVENT_CANCELLED")).toBe(true);
  });

  it("rejects RSVPs to a cancelled event", async () => {
    const res = await request(app)
      .post(`/api/v1/events/${eventId}/rsvp`)
      .set("Authorization", `Bearer ${stranger}`)
      .send({ status: "GOING" });
    expect(res.status).toBe(403);
  });
});
