import { describe, it, expect, vi, beforeEach } from "vitest";
import request from "supertest";

// Mock Prisma and Redis so this suite runs without live infra — it verifies
// the HTTP contract, validation, and token-rotation logic in isolation.
vi.mock("../config/prisma", () => {
  const users = new Map<string, any>();
  const refreshTokens = new Map<string, any>();

  return {
    prisma: {
      user: {
        findFirst: vi.fn(async ({ where }: any) => {
          for (const u of users.values()) {
            if (where.OR?.some((c: any) => u.email === c.email || u.username === c.username)) return u;
          }
          return null;
        }),
        findUnique: vi.fn(async ({ where }: any) => {
          if (where.email) return [...users.values()].find((u) => u.email === where.email) ?? null;
          if (where.id) return users.get(where.id) ?? null;
          return null;
        }),
        create: vi.fn(async ({ data }: any) => {
          const user = { id: `u_${users.size + 1}`, role: "USER", isActive: true, isBanned: false, ...data };
          users.set(user.id, user);
          return user;
        }),
      },
      refreshToken: {
        create: vi.fn(async ({ data }: any) => {
          const token = { id: `rt_${refreshTokens.size + 1}`, revokedAt: null, ...data };
          refreshTokens.set(token.tokenHash, token);
          return token;
        }),
        findUnique: vi.fn(async ({ where }: any) => refreshTokens.get(where.tokenHash) ?? null),
        update: vi.fn(async ({ where, data }: any) => {
          const entry = [...refreshTokens.values()].find((t) => t.id === where.id);
          Object.assign(entry, data);
          return entry;
        }),
        updateMany: vi.fn(async ({ where, data }: any) => {
          let count = 0;
          for (const t of refreshTokens.values()) {
            const matchesUser = where.userId !== undefined && t.userId === where.userId;
            const matchesToken = where.tokenHash !== undefined && t.tokenHash === where.tokenHash;
            if (!matchesUser && !matchesToken) continue;

            if (where.revokedAt === null && t.revokedAt !== null) continue;
            if (where.expiresAt?.gt && !(t.expiresAt > where.expiresAt.gt)) continue;

            Object.assign(t, data);
            count += 1;
          }
          return { count };
        }),
      },
      auditLog: { create: vi.fn(async () => ({})) },
    },
  };
});

vi.mock("../config/redis", () => ({
  redis: { sendCommand: vi.fn(async () => "OK"), isOpen: true, connect: vi.fn(), quit: vi.fn(), on: vi.fn() },
  connectRedis: vi.fn(async () => {}),
}));

// Rate limiting has its own focused test; here we only exercise auth logic,
// so use pass-through middleware instead of simulating Redis's Lua EVAL shape.
vi.mock("../middleware/rateLimit", () => ({
  authRateLimiter: (_req: unknown, _res: unknown, next: () => void) => next(),
  apiRateLimiter: (_req: unknown, _res: unknown, next: () => void) => next(),
}));

process.env.JWT_ACCESS_SECRET = "a".repeat(32);
process.env.DATABASE_URL = "postgresql://test";
process.env.REDIS_URL = "redis://test";

const { createApp } = await import("../app");

describe("Auth flow", () => {
  const app = createApp();
  const user = {
    email: "driver@example.com",
    username: "driver_99",
    password: "SuperSecret123",
    displayName: "Driver Ninety Nine",
  };

  it("rejects registration with a weak password", async () => {
    const res = await request(app)
      .post("/api/v1/auth/register")
      .send({ ...user, password: "weak" });
    expect(res.status).toBe(400);
  });

  it("registers a new user", async () => {
    const res = await request(app).post("/api/v1/auth/register").send(user);
    expect(res.status).toBe(201);
    expect(res.body.data.email).toBe(user.email);
    expect(res.body.data.passwordHash).toBeUndefined();
  });

  it("rejects duplicate registration", async () => {
    const res = await request(app).post("/api/v1/auth/register").send(user);
    expect(res.status).toBe(409);
  });

  it("logs in and receives an access token + refresh cookie", async () => {
    const res = await request(app)
      .post("/api/v1/auth/login")
      .send({ email: user.email, password: user.password });
    expect(res.status).toBe(200);
    expect(res.body.data.accessToken).toBeTruthy();
    expect(res.headers["set-cookie"]?.[0]).toMatch(/cartok_refresh=/);
  });

  it("rejects login with wrong password", async () => {
    const res = await request(app)
      .post("/api/v1/auth/login")
      .send({ email: user.email, password: "WrongPassword123" });
    expect(res.status).toBe(401);
  });

  it("rotates the refresh token and rejects reuse of the old one", async () => {
    const loginRes = await request(app)
      .post("/api/v1/auth/login")
      .send({ email: user.email, password: user.password });
    const cookie = loginRes.headers["set-cookie"][0];

    const refreshRes = await request(app).post("/api/v1/auth/refresh").set("Cookie", cookie);
    expect(refreshRes.status).toBe(200);
    expect(refreshRes.body.data.accessToken).toBeTruthy();

    // Reusing the original (now-rotated) cookie must fail.
    const reuseRes = await request(app).post("/api/v1/auth/refresh").set("Cookie", cookie);
    expect(reuseRes.status).toBe(401);
  });

  it("blocks protected routes without a token", async () => {
    const res = await request(app).get("/api/v1/users/me");
    expect(res.status).toBe(401);
  });

  it("only lets exactly one of two concurrent rotation attempts on the same token succeed", async () => {
    const loginRes = await request(app)
      .post("/api/v1/auth/login")
      .send({ email: user.email, password: user.password });
    const cookie = loginRes.headers["set-cookie"][0];

    // Fire both requests concurrently (not sequentially) — this is the
    // scenario the atomic-claim fix in auth.service.ts protects against:
    // two racing requests reading the same not-yet-revoked token.
    const [first, second] = await Promise.all([
      request(app).post("/api/v1/auth/refresh").set("Cookie", cookie),
      request(app).post("/api/v1/auth/refresh").set("Cookie", cookie),
    ]);

    const statuses = [first.status, second.status].sort();
    expect(statuses).toEqual([200, 401]);
  });
});
