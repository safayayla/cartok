import { z } from "zod";

const listQuery = z.object({
  cursor: z.string().uuid().optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

const notificationIdParams = z.object({ notificationId: z.string().uuid() });

export const listNotificationsSchema = { query: listQuery };
export const notificationIdParamSchema = { params: notificationIdParams };
