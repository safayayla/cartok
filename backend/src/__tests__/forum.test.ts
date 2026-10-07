import { describe, it, expect, vi, beforeEach } from "vitest";
import request from "supertest";
import jwt from "jsonwebtoken";
import { randomUUID } from "node:crypto";

// In-memory Prisma mock covering the forum + notification models used here.
vi.mock("../config/prisma", () => {
  const categories = new Map<string, any>();
  const threads = new Map<string, any>();
  const posts = new Map<string, any>();
  const votes = new Map<string, any>();
  const notifications = new Map<string, any>();
  const bookmarks = new Map<string, any>();
  const nextId = (_prefix: string) => randomUUID();

  return {
    prisma: {
      forumCategory: {
        findMany: vi.fn(async () => [...categories.values()].sort((a, b) => a.sortOrder - b.sortOrder)),
        findUnique: vi.fn(async ({ where }: any) => {
          if (where.id) return categories.get(where.id) ?? null;
          if (where.slug) return [...categories.values()].find((c) => c.slug === where.slug) ?? null;
          return null;
        }),
        create: vi.fn(async ({ data }: any) => {
          const cat = { id: nextId("cat"), ...data };
          categories.set(cat.id, cat);
          return cat;
        }),
      },
      forumThread: {
        findUnique: vi.fn(async ({ where }: any) => {
          if (where.id) return threads.get(where.id) ?? null;
          if (where.categoryId_slug) {
            return (
              [...threads.values()].find(
                (t) => t.categoryId === where.categoryId_slug.categoryId && t.slug === where.categoryId_slug.slug
              ) ?? null
            );
          }
          return null;
        }),
        findMany: vi.fn(async ({ where }: any) =>
          [...threads.values()].filter((t) => t.categoryId === where.categoryId)
        ),
        create: vi.fn(async ({ data }: any) => {
          const thread = {
            id: nextId("thread"),
            isPinned: false,
            isLocked: false,
            viewCount: 0,
            createdAt: new Date(),
            updatedAt: new Date(),
            ...data,
          };
          threads.set(thread.id, thread);
          return thread;
        }),
        update: vi.fn(async ({ where, data }: any) => {
          const thread = threads.get(where.id);
          if (data.viewCount?.increment) thread.viewCount += data.viewCount.increment;
          if (data.updatedAt) thread.updatedAt = data.updatedAt;
          return thread;
        }),
      },
      forumPost: {
        findUnique: vi.fn(async ({ where }: any) => posts.get(where.id) ?? null),
        findFirst: vi.fn(async ({ where }: any) => {
          const post = posts.get(where.id);
          return post && post.threadId === where.threadId ? post : null;
        }),
        findMany: vi.fn(async ({ where }: any) =>
          [...posts.values()]
            .filter((p) => p.threadId === where.threadId)
            .map((p) => ({
              ...p,
              author: { id: p.authorId, username: p.authorId, displayName: p.authorId, avatarUrl: null },
            }))
        ),
        create: vi.fn(async ({ data }: any) => {
          const post = { id: nextId("post"), isDeleted: false, score: 0, createdAt: new Date(), ...data };
          posts.set(post.id, post);
          return post;
        }),
        update: vi.fn(async ({ where, data }: any) => {
          const post = posts.get(where.id);
          if (data.score?.increment !== undefined) post.score += data.score.increment;
          else if (data.score?.decrement !== undefined) post.score -= data.score.decrement;
          else Object.assign(post, data);
          return post;
        }),
      },
      threadBookmark: {
        findUnique: vi.fn(async ({ where }: any) => {
          const key = `${where.threadId_userId.threadId}:${where.threadId_userId.userId}`;
          return bookmarks.get(key) ?? null;
        }),
        upsert: vi.fn(async ({ where, create }: any) => {
          const key = `${where.threadId_userId.threadId}:${where.threadId_userId.userId}`;
          const existing = bookmarks.get(key);
          const b = existing ?? { id: nextId("bm"), createdAt: new Date(), ...create };
          bookmarks.set(key, b);
          return b;
        }),
        deleteMany: vi.fn(async ({ where }: any) => {
          bookmarks.delete(`${where.threadId}:${where.userId}`);
          return { count: 1 };
        }),
        findMany: vi.fn(async ({ where }: any) =>
          [...bookmarks.values()]
            .filter((b) => b.userId === where.userId)
            .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
            .map((b) => ({
              ...b,
              thread: {
                ...threads.get(b.threadId),
                _count: { posts: [...posts.values()].filter((p) => p.threadId === b.threadId).length },
              },
            }))
        ),
      },
      forumVote: {
        findUnique: vi.fn(async ({ where }: any) => {
          const key = `${where.postId_userId.postId}:${where.postId_userId.userId}`;
          return votes.get(key) ?? null;
        }),
        create: vi.fn(async ({ data }: any) => {
          const vote = { id: nextId("vote"), ...data };
          votes.set(`${data.postId}:${data.userId}`, vote);
          return vote;
        }),
        update: vi.fn(async ({ where, data }: any) => {
          const key = `${where.postId_userId.postId}:${where.postId_userId.userId}`;
          const vote = votes.get(key);
          Object.assign(vote, data);
          return vote;
        }),
        delete: vi.fn(async ({ where }: any) => {
          const key = `${where.postId_userId.postId}:${where.postId_userId.userId}`;
          const vote = votes.get(key);
          votes.delete(key);
          return vote;
        }),
        upsert: vi.fn(async ({ where, create, update }: any) => {
          const key = `${where.postId_userId.postId}:${where.postId_userId.userId}`;
          const existing = votes.get(key);
          const vote = existing ? Object.assign(existing, update) : { id: nextId("vote"), ...create };
          votes.set(key, vote);
          return vote;
        }),
        deleteMany: vi.fn(async ({ where }: any) => {
          votes.delete(`${where.postId}:${where.userId}`);
          return { count: 1 };
        }),
      },
      notification: {
        create: vi.fn(async ({ data }: any) => {
          const n = { id: nextId("notif"), isRead: false, createdAt: new Date(), ...data };
          notifications.set(n.id, n);
          return n;
        }),
        findMany: vi.fn(async ({ where }: any) =>
          [...notifications.values()].filter((n) => n.recipientId === where.recipientId)
        ),
        count: vi.fn(async ({ where }: any) =>
          [...notifications.values()].filter((n) => n.recipientId === where.recipientId && !n.isRead).length
        ),
      },
      user: {
        findUnique: vi.fn(async ({ where }: any) => ({
          id: where.id,
          role: "USER",
          isActive: true,
          isBanned: false,
        })),
      },
      $transaction: vi.fn(async (fn: any) => {
        const txForumThread = {
          create: async ({ data }: any) => {
            const thread = {
              id: nextId("thread"),
              isPinned: false,
              isLocked: false,
              viewCount: 0,
              createdAt: new Date(),
              updatedAt: new Date(),
              ...data,
            };
            threads.set(thread.id, thread);
            return thread;
          },
        };
        const txForumPost = {
          create: async ({ data }: any) => {
            const post = { id: nextId("post"), isDeleted: false, score: 0, createdAt: new Date(), ...data };
            posts.set(post.id, post);
            return post;
          },
          update: async ({ where, data }: any) => {
            const post = posts.get(where.id);
            if (data.score?.increment !== undefined) post.score += data.score.increment;
            else if (data.score?.decrement !== undefined) post.score -= data.score.decrement;
            else Object.assign(post, data);
            return post;
          },
        };
        const txForumVote = {
          findUnique: async ({ where }: any) => {
            const key = `${where.postId_userId.postId}:${where.postId_userId.userId}`;
            return votes.get(key) ?? null;
          },
          create: async ({ data }: any) => {
            const vote = { id: nextId("vote"), ...data };
            votes.set(`${data.postId}:${data.userId}`, vote);
            return vote;
          },
          update: async ({ where, data }: any) => {
            const key = `${where.postId_userId.postId}:${where.postId_userId.userId}`;
            const vote = votes.get(key);
            Object.assign(vote, data);
            return vote;
          },
          delete: async ({ where }: any) => {
            const key = `${where.postId_userId.postId}:${where.postId_userId.userId}`;
            const vote = votes.get(key);
            votes.delete(key);
            return vote;
          },
        };
        return fn({ forumThread: txForumThread, forumPost: txForumPost, forumVote: txForumVote });
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

describe("Forum module", () => {
  const app = createApp();
  const alice = tokenFor("user_alice");
  const bob = tokenFor("user_bob");
  let categoryId: string;
  let threadId: string;
  let firstPostId: string;

  it("creates a category", async () => {
    const res = await request(app)
      .post("/api/v1/forum/categories")
      .set("Authorization", `Bearer ${tokenFor("admin")}`)
      .send({ name: "Engine Builds", sortOrder: 1 });
    // This user has role USER in our mock (not ADMIN), so this should be forbidden.
    expect(res.status).toBe(403);
  });

  it("blocks thread creation without auth", async () => {
    const res = await request(app).post("/api/v1/forum/categories/nonexistent/threads").send({
      title: "Hello",
      content: "World",
    });
    expect(res.status).toBe(401);
  });

  it("creates a thread once a category exists (seeded directly)", async () => {
    // Seed a category via the mocked prisma directly, bypassing RBAC for test setup.
    const { prisma } = await import("../config/prisma");
    const category = await (prisma as any).forumCategory.create({
      data: { name: "Engine Builds", slug: "engine-builds", sortOrder: 1 },
    });
    categoryId = category.id;

    const res = await request(app)
      .post(`/api/v1/forum/categories/${categoryId}/threads`)
      .set("Authorization", `Bearer ${alice}`)
      .send({ title: "My LS swap thread", content: "Starting the build log here." });

    expect(res.status).toBe(201);
    expect(res.body.data.title).toBe("My LS swap thread");
    threadId = res.body.data.id;
  });

  it("fetches the thread with its first post", async () => {
    const res = await request(app).get(`/api/v1/forum/threads/${threadId}`);
    expect(res.status).toBe(200);
    expect(res.body.data.posts).toHaveLength(1);
    firstPostId = res.body.data.posts[0].id;
  });

  it("lets another user reply and notifies the thread author", async () => {
    const res = await request(app)
      .post(`/api/v1/forum/threads/${threadId}/posts`)
      .set("Authorization", `Bearer ${bob}`)
      .send({ content: "Nice build, what heads are you running?" });

    expect(res.status).toBe(201);

    const notifRes = await request(app)
      .get("/api/v1/notifications")
      .set("Authorization", `Bearer ${alice}`);
    expect(notifRes.status).toBe(200);
    expect(notifRes.body.data.some((n: any) => n.type === "THREAD_REPLY")).toBe(true);
  });

  it("does not notify a user about their own reply", async () => {
    await request(app)
      .post(`/api/v1/forum/threads/${threadId}/posts`)
      .set("Authorization", `Bearer ${alice}`)
      .send({ content: "Replying to my own thread" });

    const notifRes = await request(app)
      .get("/api/v1/notifications")
      .set("Authorization", `Bearer ${alice}`);
    // Only Bob's reply should have generated a notification for Alice, not her own.
    expect(notifRes.body.data.filter((n: any) => n.type === "THREAD_REPLY")).toHaveLength(1);
  });

  it("upvotes a post and reflects the score", async () => {
    const voteRes = await request(app)
      .post(`/api/v1/forum/threads/${threadId}/posts/${firstPostId}/vote`)
      .set("Authorization", `Bearer ${bob}`)
      .send({ value: 1 });
    expect(voteRes.status).toBe(200);

    const threadRes = await request(app).get(`/api/v1/forum/threads/${threadId}`);
    const post = threadRes.body.data.posts.find((p: any) => p.id === firstPostId);
    expect(post.score).toBe(1);
  });

  it("flips an upvote to a downvote by exactly 2, not 1", async () => {
    // Bob currently has +1 on this post from the previous test. Flipping to
    // -1 should move the score by 2 (removing the +1 AND applying the -1),
    // not by 1 — this is exactly the kind of off-by-one that a naive
    // increment-only implementation gets wrong.
    const before = await request(app).get(`/api/v1/forum/threads/${threadId}`);
    const scoreBefore = before.body.data.posts.find((p: any) => p.id === firstPostId).score;

    await request(app)
      .post(`/api/v1/forum/threads/${threadId}/posts/${firstPostId}/vote`)
      .set("Authorization", `Bearer ${bob}`)
      .send({ value: -1 });

    const after = await request(app).get(`/api/v1/forum/threads/${threadId}`);
    const scoreAfter = after.body.data.posts.find((p: any) => p.id === firstPostId).score;

    expect(scoreAfter).toBe(scoreBefore - 2);
  });

  it("resubmitting the same vote value is a no-op on score", async () => {
    const before = await request(app).get(`/api/v1/forum/threads/${threadId}`);
    const scoreBefore = before.body.data.posts.find((p: any) => p.id === firstPostId).score;

    await request(app)
      .post(`/api/v1/forum/threads/${threadId}/posts/${firstPostId}/vote`)
      .set("Authorization", `Bearer ${bob}`)
      .send({ value: -1 }); // same value Bob already has from the previous test

    const after = await request(app).get(`/api/v1/forum/threads/${threadId}`);
    const scoreAfter = after.body.data.posts.find((p: any) => p.id === firstPostId).score;

    expect(scoreAfter).toBe(scoreBefore);
  });

  it("removing a vote reverses its exact contribution to the score", async () => {
    const before = await request(app).get(`/api/v1/forum/threads/${threadId}`);
    const scoreBefore = before.body.data.posts.find((p: any) => p.id === firstPostId).score;

    await request(app)
      .delete(`/api/v1/forum/threads/${threadId}/posts/${firstPostId}/vote`)
      .set("Authorization", `Bearer ${bob}`);

    const after = await request(app).get(`/api/v1/forum/threads/${threadId}`);
    const scoreAfter = after.body.data.posts.find((p: any) => p.id === firstPostId).score;

    // Bob's vote was -1 at this point, so removing it should move the score up by 1.
    expect(scoreAfter).toBe(scoreBefore + 1);
  });

  it("prevents editing someone else's post", async () => {
    const res = await request(app)
      .patch(`/api/v1/forum/threads/${threadId}/posts/${firstPostId}`)
      .set("Authorization", `Bearer ${bob}`)
      .send({ content: "hijacked" });
    expect(res.status).toBe(403);
  });

  it("soft-deletes a post as its author", async () => {
    const res = await request(app)
      .delete(`/api/v1/forum/threads/${threadId}/posts/${firstPostId}`)
      .set("Authorization", `Bearer ${alice}`);
    expect(res.status).toBe(204);

    const threadRes = await request(app).get(`/api/v1/forum/threads/${threadId}`);
    const post = threadRes.body.data.posts.find((p: any) => p.id === firstPostId);
    expect(post.content).toBe("[deleted]");
  });

  it("bookmarks a thread and reflects isBookmarkedByMe for that user only", async () => {
    const bookmarkRes = await request(app)
      .post(`/api/v1/forum/threads/${threadId}/bookmark`)
      .set("Authorization", `Bearer ${bob}`);
    expect(bookmarkRes.status).toBe(204);

    const bobView = await request(app)
      .get(`/api/v1/forum/threads/${threadId}`)
      .set("Authorization", `Bearer ${bob}`);
    expect(bobView.body.data.isBookmarkedByMe).toBe(true);

    const aliceView = await request(app)
      .get(`/api/v1/forum/threads/${threadId}`)
      .set("Authorization", `Bearer ${alice}`);
    expect(aliceView.body.data.isBookmarkedByMe).toBe(false);

    const anonView = await request(app).get(`/api/v1/forum/threads/${threadId}`);
    expect(anonView.body.data.isBookmarkedByMe).toBe(false);
  });

  it("bookmarking the same thread twice is idempotent", async () => {
    await request(app)
      .post(`/api/v1/forum/threads/${threadId}/bookmark`)
      .set("Authorization", `Bearer ${bob}`);

    const listRes = await request(app)
      .get("/api/v1/forum/threads/bookmarks")
      .set("Authorization", `Bearer ${bob}`);
    expect(listRes.body.data).toHaveLength(1);
  });

  it("lists bookmarked threads for the caller only", async () => {
    const bobList = await request(app)
      .get("/api/v1/forum/threads/bookmarks")
      .set("Authorization", `Bearer ${bob}`);
    expect(bobList.status).toBe(200);
    expect(bobList.body.data.some((t: any) => t.id === threadId)).toBe(true);

    const aliceList = await request(app)
      .get("/api/v1/forum/threads/bookmarks")
      .set("Authorization", `Bearer ${alice}`);
    expect(aliceList.body.data.some((t: any) => t.id === threadId)).toBe(false);
  });

  it("requires auth to list bookmarks", async () => {
    const res = await request(app).get("/api/v1/forum/threads/bookmarks");
    expect(res.status).toBe(401);
  });

  it("unbookmarks a thread", async () => {
    const res = await request(app)
      .delete(`/api/v1/forum/threads/${threadId}/bookmark`)
      .set("Authorization", `Bearer ${bob}`);
    expect(res.status).toBe(204);

    const listRes = await request(app)
      .get("/api/v1/forum/threads/bookmarks")
      .set("Authorization", `Bearer ${bob}`);
    expect(listRes.body.data.some((t: any) => t.id === threadId)).toBe(false);
  });

  it("rejects bookmarking a nonexistent thread", async () => {
    const res = await request(app)
      .post(`/api/v1/forum/threads/${randomUUID()}/bookmark`)
      .set("Authorization", `Bearer ${bob}`);
    expect(res.status).toBe(404);
  });
});
