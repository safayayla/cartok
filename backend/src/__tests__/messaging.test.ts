import { describe, it, expect, vi } from "vitest";
import request from "supertest";
import jwt from "jsonwebtoken";
import { randomUUID } from "node:crypto";

vi.mock("../config/prisma", () => {
  const users = new Map<string, any>();
  const conversations = new Map<string, any>();
  const participants = new Map<string, any>(); // keyed by `${conversationId}:${userId}`
  const messages = new Map<string, any>();
  const nextId = () => randomUUID();

  // Seed users so getOrCreateDm can resolve usernames.
  users.set("alice", { id: "user_alice", username: "alice" });
  users.set("bob", { id: "user_bob", username: "bob" });
  users.set("carol", { id: "user_carol", username: "carol" });

  function hydrateConversation(conversationId: string) {
    const convo = conversations.get(conversationId);
    const convoParticipants = [...participants.values()].filter((p) => p.conversationId === conversationId);
    return {
      ...convo,
      participants: convoParticipants.map((p) => ({
        ...p,
        user: { id: p.userId, username: p.userId, displayName: p.userId, avatarUrl: null },
      })),
    };
  }

  return {
    prisma: {
      user: {
        findUnique: vi.fn(async ({ where }: any) => {
          if (where.username) return users.get(where.username) ?? null;
          return [...users.values()].find((u) => u.id === where.id) ?? null;
        }),
      },
      conversation: {
        findFirst: vi.fn(async ({ where }: any) => {
          const [aClause, bClause] = where.AND;
          const userA = aClause.participants.some.userId;
          const userB = bClause.participants.some.userId;
          const found = [...conversations.values()].find((c) => {
            if (c.isGroup !== false) return false;
            const ids = [...participants.values()].filter((p) => p.conversationId === c.id).map((p) => p.userId);
            return ids.includes(userA) && ids.includes(userB);
          });
          return found ? hydrateConversation(found.id) : null;
        }),
        create: vi.fn(async ({ data }: any) => {
          const id = nextId();
          const convo = { id, isGroup: data.isGroup, createdAt: new Date(), updatedAt: new Date() };
          conversations.set(id, convo);
          for (const p of data.participants.create) {
            const pid = nextId();
            participants.set(`${id}:${p.userId}`, { id: pid, conversationId: id, userId: p.userId, lastReadAt: null, joinedAt: new Date() });
          }
          return hydrateConversation(id);
        }),
        update: vi.fn(async ({ where }: any) => {
          const convo = conversations.get(where.id);
          convo.updatedAt = new Date();
          return convo;
        }),
      },
      conversationParticipant: {
        findUnique: vi.fn(async ({ where }: any) => {
          const { conversationId, userId } = where.conversationId_userId;
          return participants.get(`${conversationId}:${userId}`) ?? null;
        }),
        findMany: vi.fn(async ({ where }: any) =>
          [...participants.values()]
            .filter((p) => p.userId === where.userId)
            .map((p) => ({
              ...p,
              conversation: {
                ...conversations.get(p.conversationId),
                participants: [...participants.values()]
                  .filter((pp) => pp.conversationId === p.conversationId)
                  .map((pp) => ({
                    ...pp,
                    user: { id: pp.userId, username: pp.userId, displayName: pp.userId, avatarUrl: null },
                  })),
                messages: [...messages.values()]
                  .filter((m) => m.conversationId === p.conversationId)
                  .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
                  .slice(0, 1),
              },
            }))
            .sort((a, b) => b.conversation.updatedAt.getTime() - a.conversation.updatedAt.getTime())
        ),
        update: vi.fn(async ({ where, data }: any) => {
          const { conversationId, userId } = where.conversationId_userId;
          const p = participants.get(`${conversationId}:${userId}`);
          Object.assign(p, data);
          return p;
        }),
      },
      message: {
        create: vi.fn(async ({ data }: any) => {
          const m = { id: nextId(), createdAt: new Date(), ...data };
          messages.set(m.id, m);
          return { ...m, sender: { id: m.senderId, username: m.senderId, displayName: m.senderId, avatarUrl: null } };
        }),
        findMany: vi.fn(async ({ where }: any) =>
          [...messages.values()]
            .filter((m) => m.conversationId === where.conversationId)
            .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
            .map((m) => ({ ...m, sender: { id: m.senderId, username: m.senderId, displayName: m.senderId, avatarUrl: null } }))
        ),
      },
      $transaction: vi.fn(async (ops: any[]) => Promise.all(ops)),
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

describe("Messaging module", () => {
  const app = createApp();
  const alice = tokenFor("user_alice");
  const bob = tokenFor("user_bob");
  const carol = tokenFor("user_carol");
  let conversationId: string;

  it("requires authentication", async () => {
    const res = await request(app).get("/api/v1/messaging/conversations");
    expect(res.status).toBe(401);
  });

  it("rejects messaging yourself", async () => {
    const res = await request(app)
      .post("/api/v1/messaging/conversations/dm/alice")
      .set("Authorization", `Bearer ${alice}`);
    expect(res.status).toBe(400);
  });

  it("404s for an unknown username", async () => {
    const res = await request(app)
      .post("/api/v1/messaging/conversations/dm/nobody")
      .set("Authorization", `Bearer ${alice}`);
    expect(res.status).toBe(404);
  });

  it("creates a DM conversation between two users", async () => {
    const res = await request(app)
      .post("/api/v1/messaging/conversations/dm/bob")
      .set("Authorization", `Bearer ${alice}`);
    expect(res.status).toBe(200);
    expect(res.body.data.participants).toHaveLength(2);
    conversationId = res.body.data.id;
  });

  it("returns the same conversation on a second get-or-create call", async () => {
    const res = await request(app)
      .post("/api/v1/messaging/conversations/dm/bob")
      .set("Authorization", `Bearer ${alice}`);
    expect(res.body.data.id).toBe(conversationId);

    const fromBob = await request(app)
      .post("/api/v1/messaging/conversations/dm/alice")
      .set("Authorization", `Bearer ${bob}`);
    expect(fromBob.body.data.id).toBe(conversationId);
  });

  it("blocks a non-participant from sending a message", async () => {
    const res = await request(app)
      .post(`/api/v1/messaging/conversations/${conversationId}/messages`)
      .set("Authorization", `Bearer ${carol}`)
      .send({ content: "sneaky" });
    expect(res.status).toBe(404);
  });

  it("lets a participant send a message", async () => {
    const res = await request(app)
      .post(`/api/v1/messaging/conversations/${conversationId}/messages`)
      .set("Authorization", `Bearer ${alice}`)
      .send({ content: "Hey, is the K24 still available?" });
    expect(res.status).toBe(201);
    expect(res.body.data.content).toBe("Hey, is the K24 still available?");
  });

  it("lists messages for a participant, newest first", async () => {
    await request(app)
      .post(`/api/v1/messaging/conversations/${conversationId}/messages`)
      .set("Authorization", `Bearer ${bob}`)
      .send({ content: "Yep, still have it!" });

    const res = await request(app)
      .get(`/api/v1/messaging/conversations/${conversationId}/messages`)
      .set("Authorization", `Bearer ${alice}`);
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(2);
    expect(res.body.data[0].content).toBe("Yep, still have it!");
  });

  it("blocks a non-participant from reading messages", async () => {
    const res = await request(app)
      .get(`/api/v1/messaging/conversations/${conversationId}/messages`)
      .set("Authorization", `Bearer ${carol}`);
    expect(res.status).toBe(404);
  });

  it("shows the conversation as unread for the recipient until marked read", async () => {
    const bobList = await request(app)
      .get("/api/v1/messaging/conversations")
      .set("Authorization", `Bearer ${bob}`);
    expect(bobList.body.data[0].isUnread).toBe(false);

    const aliceList = await request(app)
      .get("/api/v1/messaging/conversations")
      .set("Authorization", `Bearer ${alice}`);
    expect(aliceList.body.data[0].isUnread).toBe(true);

    await request(app)
      .post(`/api/v1/messaging/conversations/${conversationId}/read`)
      .set("Authorization", `Bearer ${alice}`);

    const aliceListAfter = await request(app)
      .get("/api/v1/messaging/conversations")
      .set("Authorization", `Bearer ${alice}`);
    expect(aliceListAfter.body.data[0].isUnread).toBe(false);
  });

  it("blocks a non-participant from marking a conversation read", async () => {
    const res = await request(app)
      .post(`/api/v1/messaging/conversations/${conversationId}/read`)
      .set("Authorization", `Bearer ${carol}`);
    expect(res.status).toBe(404);
  });
});
