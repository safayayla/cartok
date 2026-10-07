import { z } from "zod";

export const slugify = (s: string) =>
  s
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");

const createGarageBody = z.object({
  name: z.string().min(1).max(60),
  description: z.string().max(500).optional(),
  coverUrl: z.string().url().max(2048).optional(),
  isPublic: z.boolean().default(true),
});

const updateGarageBody = z.object({
  name: z.string().min(1).max(60).optional(),
  description: z.string().max(500).optional(),
  coverUrl: z.string().url().max(2048).optional(),
  isPublic: z.boolean().optional(),
});

const garageIdParams = z.object({ garageId: z.string().uuid() });
const listQuery = z.object({
  cursor: z.string().uuid().optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});
const browseQuery = listQuery.extend({
  search: z.string().trim().min(1).max(140).optional(),
});

export const createGarageSchema = { body: createGarageBody };
export const updateGarageSchema = { body: updateGarageBody, params: garageIdParams };
export const garageIdParamSchema = { params: garageIdParams };
export const listGaragesSchema = { query: listQuery };
export const browseGaragesSchema = { query: browseQuery };

export type CreateGarageInput = z.infer<typeof createGarageBody>;
export type UpdateGarageInput = z.infer<typeof updateGarageBody>;
