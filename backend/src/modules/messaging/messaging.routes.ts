import { Router } from "express";
import { messagingController } from "./messaging.controller";
import { requireAuth } from "../../middleware/auth";
import { validate } from "../../middleware/validate";
import {
  dmParamSchema,
  listConversationsSchema,
  listMessagesSchema,
  sendMessageSchema,
  conversationIdParamSchema,
} from "./messaging.schemas";

export const messagingRouter = Router();

messagingRouter.use(requireAuth);

messagingRouter.get("/conversations", validate(listConversationsSchema), messagingController.listConversations);
messagingRouter.post("/conversations/dm/:username", validate(dmParamSchema), messagingController.getOrCreateDm);
messagingRouter.get(
  "/conversations/:conversationId/messages",
  validate(listMessagesSchema),
  messagingController.listMessages
);
messagingRouter.post(
  "/conversations/:conversationId/messages",
  validate(sendMessageSchema),
  messagingController.sendMessage
);
messagingRouter.post(
  "/conversations/:conversationId/read",
  validate(conversationIdParamSchema),
  messagingController.markRead
);
