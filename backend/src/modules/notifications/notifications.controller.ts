import { Request, Response } from "express";
import { notificationsService } from "./notifications.service";
import { asyncHandler } from "../../middleware/errors";

export const notificationsController = {
  list: asyncHandler(async (req: Request, res: Response) => {
    const { cursor, limit } = req.query as unknown as { cursor?: string; limit: number };
    const result = await notificationsService.list(req.user!.sub, { cursor, limit });
    res.json({ data: result.items, nextCursor: result.nextCursor });
  }),

  unreadCount: asyncHandler(async (req: Request, res: Response) => {
    const count = await notificationsService.unreadCount(req.user!.sub);
    res.json({ data: { count } });
  }),

  markRead: asyncHandler(async (req: Request, res: Response) => {
    const notification = await notificationsService.markRead(req.user!.sub, req.params.notificationId);
    res.json({ data: notification });
  }),

  markAllRead: asyncHandler(async (req: Request, res: Response) => {
    await notificationsService.markAllRead(req.user!.sub);
    res.status(204).send();
  }),
};
