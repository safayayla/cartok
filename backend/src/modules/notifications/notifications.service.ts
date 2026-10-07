import { prisma } from "../../config/prisma";
import type { NotificationType } from "@prisma/client";
import { Errors } from "../../middleware/errors";

export const notificationsService = {
  /**
   * Fire-and-forget notification creation, called by other modules (forum
   * replies, garage follows, vehicle verification, etc). Never throws to the
   * caller's main flow — a failed notification should never fail the action
   * that triggered it (e.g. a reply should still succeed even if the
   * notification insert fails for some reason).
   */
  async emit(params: {
    recipientId: string;
    actorId?: string | null;
    type: NotificationType;
    message: string;
    entityType?: string;
    entityId?: string;
  }) {
    // Never notify a user about their own action (e.g. replying to your own thread).
    if (params.actorId && params.actorId === params.recipientId) return;

    try {
      await prisma.notification.create({
        data: {
          recipientId: params.recipientId,
          actorId: params.actorId ?? null,
          type: params.type,
          message: params.message,
          entityType: params.entityType,
          entityId: params.entityId,
        },
      });
    } catch {
      // Swallow — notification delivery is best-effort, not transactional
      // with the action that caused it. A push/email delivery layer would
      // hook in here in a later phase (FCM/APNs credentials required).
    }
  },

  async list(userId: string, { cursor, limit = 20 }: { cursor?: string; limit?: number }) {
    const notifications = await prisma.notification.findMany({
      where: { recipientId: userId },
      orderBy: { createdAt: "desc" },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });

    const hasMore = notifications.length > limit;
    const page = hasMore ? notifications.slice(0, limit) : notifications;

    return {
      items: page,
      nextCursor: hasMore ? page[page.length - 1].id : null,
    };
  },

  async unreadCount(userId: string) {
    return prisma.notification.count({ where: { recipientId: userId, isRead: false } });
  },

  async markRead(userId: string, notificationId: string) {
    const notification = await prisma.notification.findUnique({ where: { id: notificationId } });
    if (!notification) throw Errors.notFound("Notification not found");
    if (notification.recipientId !== userId) throw Errors.forbidden();

    return prisma.notification.update({ where: { id: notificationId }, data: { isRead: true } });
  },

  async markAllRead(userId: string) {
    await prisma.notification.updateMany({
      where: { recipientId: userId, isRead: false },
      data: { isRead: true },
    });
  },
};
