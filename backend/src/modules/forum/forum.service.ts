import { prisma } from "../../config/prisma";
import { Errors } from "../../middleware/errors";
import { notificationsService } from "../notifications/notifications.service";
import { slugify, CreateThreadInput, CreatePostInput } from "./forum.schemas";

async function uniqueThreadSlug(categoryId: string, title: string): Promise<string> {
  const base = slugify(title) || "thread";
  let suffix = 0;
  while (suffix < 50) {
    const candidate = suffix === 0 ? base : `${base}-${suffix}`;
    const existing = await prisma.forumThread.findUnique({
      where: { categoryId_slug: { categoryId, slug: candidate } },
      select: { id: true },
    });
    if (!existing) return candidate;
    suffix += 1;
  }
  throw Errors.internal("Could not generate a unique thread slug");
}

export const forumService = {
  // --- Categories ---
  async listCategories() {
    return prisma.forumCategory.findMany({ orderBy: { sortOrder: "asc" } });
  },

  async createCategory(input: { name: string; description?: string; sortOrder: number }) {
    const slug = slugify(input.name) || "category";
    const existing = await prisma.forumCategory.findUnique({ where: { slug } });
    if (existing) throw Errors.conflict("A category with a similar name already exists");
    return prisma.forumCategory.create({ data: { ...input, slug } });
  },

  // --- Threads ---
  async createThread(categoryId: string, authorId: string, input: CreateThreadInput) {
    const category = await prisma.forumCategory.findUnique({ where: { id: categoryId } });
    if (!category) throw Errors.notFound("Category not found");

    const slug = await uniqueThreadSlug(categoryId, input.title);

    return prisma.$transaction(async (tx: typeof prisma) => {
      const thread = await tx.forumThread.create({
        data: { categoryId, authorId, title: input.title, slug },
      });
      await tx.forumPost.create({
        data: { threadId: thread.id, authorId, content: input.content },
      });
      return thread;
    });
  },

  async listThreads(categoryId: string, { cursor, limit }: { cursor?: string; limit: number }) {
    const category = await prisma.forumCategory.findUnique({ where: { id: categoryId } });
    if (!category) throw Errors.notFound("Category not found");

    const threads = await prisma.forumThread.findMany({
      where: { categoryId },
      orderBy: [{ isPinned: "desc" }, { updatedAt: "desc" }],
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: { _count: { select: { posts: true } } },
    });

    const hasMore = threads.length > limit;
    const page = hasMore ? threads.slice(0, limit) : threads;
    return { items: page, nextCursor: hasMore ? page[page.length - 1].id : null };
  },

  async getThread(threadId: string, viewerId?: string) {
    const thread = await prisma.forumThread.findUnique({
      where: { id: threadId },
      include: { category: true },
    });
    if (!thread) throw Errors.notFound("Thread not found");

    // Increment view count best-effort; not critical if this races.
    await prisma.forumThread.update({ where: { id: threadId }, data: { viewCount: { increment: 1 } } });

    const isBookmarkedByMe = viewerId
      ? Boolean(await prisma.threadBookmark.findUnique({ where: { threadId_userId: { threadId, userId: viewerId } } }))
      : false;

    return { ...thread, isBookmarkedByMe };
  },

  async bookmark(threadId: string, userId: string) {
    const thread = await prisma.forumThread.findUnique({ where: { id: threadId }, select: { id: true } });
    if (!thread) throw Errors.notFound("Thread not found");

    await prisma.threadBookmark.upsert({
      where: { threadId_userId: { threadId, userId } },
      create: { threadId, userId },
      update: {},
    });
  },

  async unbookmark(threadId: string, userId: string) {
    await prisma.threadBookmark.deleteMany({ where: { threadId, userId } });
  },

  async listBookmarkedThreads(userId: string, { cursor, limit }: { cursor?: string; limit: number }) {
    const bookmarks = await prisma.threadBookmark.findMany({
      where: { userId },
      orderBy: { createdAt: "desc" },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: { thread: { include: { _count: { select: { posts: true } } } } },
    });

    const hasMore = bookmarks.length > limit;
    const page = hasMore ? bookmarks.slice(0, limit) : bookmarks;
    return {
      items: page.map((b: { thread: unknown }) => b.thread),
      nextCursor: hasMore ? page[page.length - 1].id : null,
    };
  },

  async assertNotLocked(threadId: string) {
    const thread = await prisma.forumThread.findUnique({ where: { id: threadId }, select: { isLocked: true } });
    if (!thread) throw Errors.notFound("Thread not found");
    if (thread.isLocked) throw Errors.forbidden("This thread is locked");
  },

  // --- Posts ---
  async listPosts(threadId: string) {
    const posts = await prisma.forumPost.findMany({
      where: { threadId },
      orderBy: { createdAt: "asc" },
      include: {
        author: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
      },
    });

    return posts.map((p: { isDeleted: boolean; content: string }) => ({
      ...p,
      content: p.isDeleted ? "[deleted]" : p.content,
    }));
  },

  async createPost(threadId: string, authorId: string, input: CreatePostInput) {
    await this.assertNotLocked(threadId);

    const thread = await prisma.forumThread.findUnique({ where: { id: threadId } });
    if (!thread) throw Errors.notFound("Thread not found");

    let parent = null;
    if (input.parentId) {
      parent = await prisma.forumPost.findFirst({ where: { id: input.parentId, threadId } });
      if (!parent) throw Errors.notFound("Parent post not found in this thread");
    }

    const post = await prisma.forumPost.create({
      data: { threadId, authorId, content: input.content, parentId: input.parentId },
    });

    await prisma.forumThread.update({ where: { id: threadId }, data: { updatedAt: new Date() } });

    // Notify the thread's original author, and separately the parent-post
    // author if this is a nested reply (emit() already no-ops on self-notify).
    await notificationsService.emit({
      recipientId: thread.authorId,
      actorId: authorId,
      type: "THREAD_REPLY",
      message: `replied to your thread "${thread.title}"`,
      entityType: "ForumThread",
      entityId: threadId,
    });

    if (parent && parent.authorId !== thread.authorId) {
      await notificationsService.emit({
        recipientId: parent.authorId,
        actorId: authorId,
        type: "THREAD_REPLY",
        message: `replied to your comment in "${thread.title}"`,
        entityType: "ForumPost",
        entityId: post.id,
      });
    }

    return post;
  },

  async assertPostAuthor(postId: string, userId: string) {
    const post = await prisma.forumPost.findUnique({ where: { id: postId }, select: { authorId: true } });
    if (!post) throw Errors.notFound("Post not found");
    if (post.authorId !== userId) throw Errors.forbidden("You can only edit your own posts");
    return post;
  },

  async updatePost(postId: string, userId: string, content: string) {
    await this.assertPostAuthor(postId, userId);
    return prisma.forumPost.update({ where: { id: postId }, data: { content, editedAt: new Date() } });
  },

  async deletePost(postId: string, userId: string, isModerator: boolean) {
    const post = await prisma.forumPost.findUnique({ where: { id: postId }, select: { authorId: true } });
    if (!post) throw Errors.notFound("Post not found");
    if (post.authorId !== userId && !isModerator) throw Errors.forbidden();

    // Soft delete only: the underlying content is preserved for moderation
    // review and audit purposes and is never returned to normal API
    // consumers — listPosts() already masks it to "[deleted]" at read time.
    // Erasing it here would make moderation and abuse investigation
    // impossible and would defeat the point of a *soft* delete.
    await prisma.forumPost.update({ where: { id: postId }, data: { isDeleted: true } });
  },

  // --- Votes ---
  async vote(postId: string, userId: string, value: 1 | -1) {
    const post = await prisma.forumPost.findUnique({ where: { id: postId }, select: { authorId: true } });
    if (!post) throw Errors.notFound("Post not found");

    const vote = await prisma.$transaction(async (tx: typeof prisma) => {
      const existing = await tx.forumVote.findUnique({ where: { postId_userId: { postId, userId } } });

      // Score is a denormalized counter, not a live SUM(), so every write
      // path must apply the exact delta needed to keep it correct:
      //  - no prior vote: score moves by the full new value
      //  - flipping (+1 -> -1 or vice versa): score moves by 2x the new value
      //  - resubmitting the same value: no change, and skip the write entirely
      const delta = existing ? (existing.value === value ? 0 : value - existing.value) : value;

      const result = existing
        ? await tx.forumVote.update({ where: { postId_userId: { postId, userId } }, data: { value } })
        : await tx.forumVote.create({ data: { postId, userId, value } });

      if (delta !== 0) {
        await tx.forumPost.update({ where: { id: postId }, data: { score: { increment: delta } } });
      }

      return result;
    });

    if (value === 1) {
      await notificationsService.emit({
        recipientId: post.authorId,
        actorId: userId,
        type: "POST_VOTE",
        message: "upvoted your post",
        entityType: "ForumPost",
        entityId: postId,
      });
    }

    return vote;
  },

  async removeVote(postId: string, userId: string) {
    await prisma.$transaction(async (tx: typeof prisma) => {
      const existing = await tx.forumVote.findUnique({ where: { postId_userId: { postId, userId } } });
      if (!existing) return; // nothing to remove, and nothing to adjust

      await tx.forumVote.delete({ where: { postId_userId: { postId, userId } } });
      await tx.forumPost.update({ where: { id: postId }, data: { score: { decrement: existing.value } } });
    });
  },
};
