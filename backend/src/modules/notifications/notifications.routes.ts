import { Router } from "express";
import { notificationsController } from "./notifications.controller";
import { requireAuth } from "../../middleware/auth";
import { validate } from "../../middleware/validate";
import { listNotificationsSchema, notificationIdParamSchema } from "./notifications.schemas";

export const notificationsRouter = Router();

notificationsRouter.use(requireAuth);

notificationsRouter.get("/", validate(listNotificationsSchema), notificationsController.list);
notificationsRouter.get("/unread-count", notificationsController.unreadCount);
notificationsRouter.post(
  "/:notificationId/read",
  validate(notificationIdParamSchema),
  notificationsController.markRead
);
notificationsRouter.post("/read-all", notificationsController.markAllRead);
