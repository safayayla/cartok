import crypto from "node:crypto";
import { prisma } from "../../config/prisma";
import { Errors } from "../../middleware/errors";
import { notificationsService } from "../notifications/notifications.service";
import type { CreateEventInput, UpdateEventInput } from "./events.schemas";

function generateCheckInCode(): string {
  // Opaque, unguessable code embedded in the event's QR — not a sequential
  // ID, so a stolen/photographed QR from one event can't be predicted for
  // another, and enumeration isn't feasible.
  return crypto.randomBytes(16).toString("hex");
}

// A check-in is only accepted in a window around the event, not any time
// forever — otherwise a leaked/old QR code stays valid indefinitely.
const CHECK_IN_OPENS_MINUTES_BEFORE = 60;
const CHECK_IN_CLOSES_HOURS_AFTER_START_WITH_NO_END = 6;

export const eventsService = {
  async create(hostId: string, input: CreateEventInput) {
    return prisma.event.create({
      data: { ...input, hostId, checkInCode: generateCheckInCode() },
    });
  },

  async list({ type, cursor, limit }: { type?: string; cursor?: string; limit: number }) {
    const events = await prisma.event.findMany({
      where: {
        isCancelled: false,
        startTime: { gte: new Date() },
        ...(type ? { type: type as never } : {}),
      },
      orderBy: { startTime: "asc" },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      // checkInCode is deliberately never selected here: it's the secret
      // embedded in the event's QR code, and this is a public, unauthenticated
      // browse endpoint. Broadcasting it here would let anyone check
      // themselves in without ever attending — see getById() below for the
      // same reasoning applied to the detail view.
      select: {
        id: true,
        type: true,
        title: true,
        description: true,
        locationName: true,
        latitude: true,
        longitude: true,
        startTime: true,
        endTime: true,
        capacity: true,
        hostId: true,
        isCancelled: true,
        createdAt: true,
        updatedAt: true,
        _count: { select: { rsvps: true } },
      },
    });

    const hasMore = events.length > limit;
    const page = hasMore ? events.slice(0, limit) : events;
    return { items: page, nextCursor: hasMore ? page[page.length - 1].id : null };
  },

  async getById(eventId: string, viewerId?: string) {
    const event = await prisma.event.findUnique({
      where: { id: eventId },
      include: {
        host: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
        _count: { select: { rsvps: true, checkIns: true } },
      },
    });
    if (!event) throw Errors.notFound("Event not found");

    // Only the host can see the actual check-in code value — they need it
    // to generate/display the QR at the venue. Everyone else (including
    // attendees, who scan the physical/displayed QR rather than reading the
    // code through the API) gets it stripped from the response.
    if (event.hostId !== viewerId) {
      const { checkInCode: _checkInCode, ...rest } = event;
      return rest;
    }
    return event;
  },

  async assertHost(eventId: string, userId: string) {
    const event = await prisma.event.findUnique({ where: { id: eventId }, select: { hostId: true } });
    if (!event) throw Errors.notFound("Event not found");
    if (event.hostId !== userId) throw Errors.forbidden("Only the host can do this");
    return event;
  },

  async update(eventId: string, userId: string, input: UpdateEventInput) {
    await this.assertHost(eventId, userId);
    return prisma.event.update({ where: { id: eventId }, data: input });
  },

  async cancel(eventId: string, userId: string) {
    await this.assertHost(eventId, userId);
    const event = await prisma.event.update({ where: { id: eventId }, data: { isCancelled: true } });

    const rsvps = await prisma.eventRsvp.findMany({
      where: { eventId, status: { in: ["GOING", "INTERESTED"] } },
      select: { userId: true },
    });

    // Best-effort fan-out; notificationsService.emit already swallows
    // individual failures so one bad notification can't abort the rest.
    await Promise.all(
      rsvps.map((r: { userId: string }) =>
        notificationsService.emit({
          recipientId: r.userId,
          type: "EVENT_CANCELLED",
          message: `"${event.title}" has been cancelled`,
          entityType: "Event",
          entityId: eventId,
        })
      )
    );

    return event;
  },

  async rsvp(eventId: string, userId: string, status: "GOING" | "INTERESTED" | "NOT_GOING") {
    const event = await prisma.event.findUnique({ where: { id: eventId } });
    if (!event) throw Errors.notFound("Event not found");
    if (event.isCancelled) throw Errors.forbidden("This event has been cancelled");

    // Capacity check-and-write must be serialized per-event, or two
    // concurrent RSVPs near capacity could both read a count under the
    // limit and both succeed, overbooking the event. A transaction alone
    // does not close this under Postgres's default READ COMMITTED isolation
    // — two concurrent transactions can both read the same count before
    // either commits. `SELECT ... FOR UPDATE` on the event row forces any
    // second concurrent RSVP for the *same* event to wait until the first
    // transaction commits, so its count read is guaranteed fresh. RSVPs to
    // different events are untouched by this and don't contend with each other.
    const rsvp = await prisma.$transaction(async (tx: typeof prisma) => {
      if (status === "GOING" && event.capacity) {
        await tx.$queryRaw`SELECT id FROM "Event" WHERE id = ${eventId} FOR UPDATE`;

        const existing = await tx.eventRsvp.findUnique({ where: { eventId_userId: { eventId, userId } } });
        const alreadyGoing = existing?.status === "GOING";
        if (!alreadyGoing) {
          const goingCount = await tx.eventRsvp.count({ where: { eventId, status: "GOING" } });
          if (goingCount >= event.capacity) throw Errors.conflict("This event is at capacity");
        }
      }

      return tx.eventRsvp.upsert({
        where: { eventId_userId: { eventId, userId } },
        create: { eventId, userId, status },
        update: { status },
      });
    });

    if (status === "GOING") {
      await notificationsService.emit({
        recipientId: event.hostId,
        actorId: userId,
        type: "EVENT_RSVP",
        message: `is going to "${event.title}"`,
        entityType: "Event",
        entityId: eventId,
      });
    }

    return rsvp;
  },

  async listAttendees(eventId: string, { cursor, limit = 50 }: { cursor?: string; limit?: number } = {}) {
    const attendees = await prisma.eventRsvp.findMany({
      where: { eventId, status: "GOING" },
      orderBy: { createdAt: "asc" },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: { user: { select: { id: true, username: true, displayName: true, avatarUrl: true } } },
    });

    const hasMore = attendees.length > limit;
    const page = hasMore ? attendees.slice(0, limit) : attendees;
    return { items: page, nextCursor: hasMore ? page[page.length - 1].id : null };
  },

  async checkIn(checkInCode: string, userId: string) {
    const event = await prisma.event.findUnique({ where: { checkInCode } });
    if (!event) throw Errors.notFound("Invalid check-in code");
    if (event.isCancelled) throw Errors.forbidden("This event has been cancelled");

    const now = new Date();
    const opensAt = new Date(event.startTime.getTime() - CHECK_IN_OPENS_MINUTES_BEFORE * 60_000);
    const closesAt = event.endTime
      ? event.endTime
      : new Date(event.startTime.getTime() + CHECK_IN_CLOSES_HOURS_AFTER_START_WITH_NO_END * 60 * 60_000);

    if (now < opensAt) throw Errors.forbidden("Check-in hasn't opened yet for this event");
    if (now > closesAt) throw Errors.forbidden("Check-in has closed for this event");

    return prisma.eventCheckIn.upsert({
      where: { eventId_userId: { eventId: event.id, userId } },
      create: { eventId: event.id, userId },
      update: {},
    });
  },
};
