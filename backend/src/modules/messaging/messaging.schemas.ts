import { z } from "zod";

const conversationIdParams = z.object({ conversationId: z.string().uuid() });
const usernameParams = z.object({ username: z.string().min(1).max(24) });

const listQuery = z.object({
  cursor: z.string().uuid().optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

const sendMessageBody = z.object({
  content: z.string().min(1).max(4000),
});

export const dmParamSchema = { params: usernameParams };
export const listConversationsSchema = { query: listQuery };
export const listMessagesSchema = { params: conversationIdParams, query: listQuery };
export const sendMessageSchema = { body: sendMessageBody, params: conversationIdParams };
export const conversationIdParamSchema = { params: conversationIdParams };
