import { z } from "zod";

const updateProfileBody = z.object({
  displayName: z.string().min(1).max(60).optional(),
  bio: z.string().max(280).optional(),
  avatarUrl: z.string().url().max(2048).optional(),
});

const usernameParams = z.object({
  username: z.string().min(1).max(24),
});

const listQuery = z.object({
  cursor: z.string().uuid().optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

const searchQuery = z.object({
  q: z.string().trim().min(1).max(60),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

export const updateProfileSchema = { body: updateProfileBody };
export const usernameParamSchema = { params: usernameParams };
export const listFollowSchema = { params: usernameParams, query: listQuery };
export const searchUsersSchema = { query: searchQuery };
