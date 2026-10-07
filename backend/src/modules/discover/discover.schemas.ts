import { z } from "zod";

const feedQuery = z.object({
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

export const getFeedSchema = { query: feedQuery };
