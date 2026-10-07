import { z } from "zod";

export const slugify = (s: string) =>
  s
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");

// --- Categories (admin-managed) ---
const createCategoryBody = z.object({
  name: z.string().min(1).max(60),
  description: z.string().max(300).optional(),
  sortOrder: z.number().int().default(0),
});
export const createCategorySchema = { body: createCategoryBody };

// --- Threads ---
const createThreadBody = z.object({
  title: z.string().min(3).max(140),
  content: z.string().min(1).max(10_000), // becomes the thread's first post
});
const categoryIdParams = z.object({ categoryId: z.string().uuid() });
const threadIdParams = z.object({ threadId: z.string().uuid() });

export const createThreadSchema = { body: createThreadBody, params: categoryIdParams };
export const categoryIdParamSchema = { params: categoryIdParams };
export const threadIdParamSchema = { params: threadIdParams };

const listThreadsQuery = z.object({
  cursor: z.string().uuid().optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});
export const listThreadsSchema = { params: categoryIdParams, query: listThreadsQuery };
export const listBookmarksSchema = { query: listThreadsQuery };

// --- Posts (replies) ---
const createPostBody = z.object({
  content: z.string().min(1).max(10_000),
  parentId: z.string().uuid().optional(),
});
export const createPostSchema = { body: createPostBody, params: threadIdParams };

const postIdParams = z.object({ threadId: z.string().uuid(), postId: z.string().uuid() });
export const postIdParamSchema = { params: postIdParams };

const updatePostBody = z.object({ content: z.string().min(1).max(10_000) });
export const updatePostSchema = { body: updatePostBody, params: postIdParams };

// --- Votes ---
const voteBody = z.object({ value: z.union([z.literal(1), z.literal(-1)]) });
export const voteSchema = { body: voteBody, params: postIdParams };

export type CreateThreadInput = z.infer<typeof createThreadBody>;
export type CreatePostInput = z.infer<typeof createPostBody>;
