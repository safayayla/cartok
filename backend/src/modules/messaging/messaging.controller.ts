import { Request, Response } from "express";
import { messagingService } from "./messaging.service";
import { asyncHandler } from "../../middleware/errors";

export const messagingController = {
  getOrCreateDm: asyncHandler(async (req: Request, res: Response) => {
    const conversation = await messagingService.getOrCreateDm(req.user!.sub, req.params.username);
    res.json({ data: conversation });
  }),

  listConversations: asyncHandler(async (req: Request, res: Response) => {
    const { cursor, limit } = req.query as unknown as { cursor?: string; limit: number };
    const result = await messagingService.listConversations(req.user!.sub, { cursor, limit });
    res.json({ data: result.items, nextCursor: result.nextCursor });
  }),

  listMessages: asyncHandler(async (req: Request, res: Response) => {
    const { cursor, limit } = req.query as unknown as { cursor?: string; limit: number };
    const result = await messagingService.listMessages(req.params.conversationId, req.user!.sub, {
      cursor,
      limit,
    });
    res.json({ data: result.items, nextCursor: result.nextCursor });
  }),

  sendMessage: asyncHandler(async (req: Request, res: Response) => {
    const message = await messagingService.sendMessage(req.params.conversationId, req.user!.sub, req.body.content);
    res.status(201).json({ data: message });
  }),

  markRead: asyncHandler(async (req: Request, res: Response) => {
    await messagingService.markRead(req.params.conversationId, req.user!.sub);
    res.status(204).send();
  }),
};
