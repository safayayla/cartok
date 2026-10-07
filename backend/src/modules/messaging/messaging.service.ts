import { prisma } from "../../config/prisma";
import { Errors } from "../../middleware/errors";

const participantSelect = { id: true, username: true, displayName: true, avatarUrl: true } as const;

export const messagingService = {
  async assertParticipant(conversationId: string, userId: string) {
    const participant = await prisma.conversationParticipant.findUnique({
      where: { conversationId_userId: { conversationId, userId } },
    });
    if (!participant) throw Errors.notFound("Conversation not found");
    return participant;
  },

  /**
   * Gets the existing 1:1 conversation with this user, or creates one.
   * Scoped to DMs only (see schema.prisma's messaging section comment) —
   * this deliberately does not accept a list of user IDs to build a group.
   */
  async getOrCreateDm(currentUserId: string, otherUsername: string) {
    const otherUser = await prisma.user.findUnique({ where: { username: otherUsername } });
    if (!otherUser) throw Errors.notFound("User not found");
    if (otherUser.id === currentUserId) throw Errors.badRequest("You can't message yourself");

    const existing = await prisma.conversation.findFirst({
      where: {
        isGroup: false,
        AND: [
          { participants: { some: { userId: currentUserId } } },
          { participants: { some: { userId: otherUser.id } } },
        ],
      },
      include: { participants: { include: { user: { select: participantSelect } } } },
    });
    if (existing) return existing;

    return prisma.conversation.create({
      data: {
        isGroup: false,
        participants: {
          create: [{ userId: currentUserId }, { userId: otherUser.id }],
        },
      },
      include: { participants: { include: { user: { select: participantSelect } } } },
    });
  },

  async listConversations(userId: string, { cursor, limit }: { cursor?: string; limit: number }) {
    const rows = await prisma.conversationParticipant.findMany({
      where: { userId },
      // Secondary sort on id breaks ties deterministically for cursor
      // pagination — sorting only by the related conversation's updatedAt
      // isn't itself a stable total order (two conversations can share a
      // timestamp), which cursor pagination needs to avoid skipping/
      // repeating rows across pages.
      orderBy: [{ conversation: { updatedAt: "desc" } }, { id: "desc" }],
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: {
        conversation: {
          include: {
            participants: { include: { user: { select: participantSelect } } },
            messages: { orderBy: { createdAt: "desc" }, take: 1 },
          },
        },
      },
    });

    const hasMore = rows.length > limit;
    const page = hasMore ? rows.slice(0, limit) : rows;

    const items = page.map(
      (row: {
        lastReadAt: Date | null;
        conversation: {
          id: string;
          updatedAt: Date;
          participants: { userId: string; user: unknown }[];
          messages: { senderId: string; createdAt: Date }[];
        };
      }) => {
        const conversation = row.conversation;
        const otherParticipant = conversation.participants.find((p) => p.userId !== userId)?.user ?? null;
        const lastMessage = conversation.messages[0] ?? null;
        const isUnread = Boolean(
          lastMessage && lastMessage.senderId !== userId && (!row.lastReadAt || lastMessage.createdAt > row.lastReadAt)
        );

        return {
          conversationId: conversation.id,
          otherParticipant,
          lastMessage,
          isUnread,
          updatedAt: conversation.updatedAt,
        };
      }
    );

    return { items, nextCursor: hasMore ? page[page.length - 1].id : null };
  },

  async listMessages(conversationId: string, userId: string, { cursor, limit }: { cursor?: string; limit: number }) {
    await this.assertParticipant(conversationId, userId);

    const messages = await prisma.message.findMany({
      where: { conversationId },
      orderBy: { createdAt: "desc" },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: { sender: { select: participantSelect } },
    });

    const hasMore = messages.length > limit;
    const page = hasMore ? messages.slice(0, limit) : messages;
    return { items: page, nextCursor: hasMore ? page[page.length - 1].id : null };
  },

  async sendMessage(conversationId: string, senderId: string, content: string) {
    await this.assertParticipant(conversationId, senderId);

    const [message] = await prisma.$transaction([
      prisma.message.create({
        data: { conversationId, senderId, content },
        include: { sender: { select: participantSelect } },
      }),
      // Bumps updatedAt (Prisma's @updatedAt only fires on an update() of
      // the model itself, not on a related create()) so the conversation
      // list sorts by most-recently-active without a separate aggregate query.
      prisma.conversation.update({ where: { id: conversationId }, data: {} }),
    ]);

    return message;
  },

  async markRead(conversationId: string, userId: string) {
    await this.assertParticipant(conversationId, userId);
    await prisma.conversationParticipant.update({
      where: { conversationId_userId: { conversationId, userId } },
      data: { lastReadAt: new Date() },
    });
  },
};
