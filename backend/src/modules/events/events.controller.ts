import { Request, Response } from "express";
import { eventsService } from "./events.service";
import { asyncHandler } from "../../middleware/errors";

export const eventsController = {
  create: asyncHandler(async (req: Request, res: Response) => {
    const event = await eventsService.create(req.user!.sub, req.body);
    res.status(201).json({ data: event });
  }),

  list: asyncHandler(async (req: Request, res: Response) => {
    const { type, cursor, limit } = req.query as unknown as { type?: string; cursor?: string; limit: number };
    const result = await eventsService.list({ type, cursor, limit });
    res.json({ data: result.items, nextCursor: result.nextCursor });
  }),

  getById: asyncHandler(async (req: Request, res: Response) => {
    const event = await eventsService.getById(req.params.eventId, req.user?.sub);
    res.json({ data: event });
  }),

  update: asyncHandler(async (req: Request, res: Response) => {
    const event = await eventsService.update(req.params.eventId, req.user!.sub, req.body);
    res.json({ data: event });
  }),

  cancel: asyncHandler(async (req: Request, res: Response) => {
    const event = await eventsService.cancel(req.params.eventId, req.user!.sub);
    res.json({ data: event });
  }),

  rsvp: asyncHandler(async (req: Request, res: Response) => {
    const rsvp = await eventsService.rsvp(req.params.eventId, req.user!.sub, req.body.status);
    res.json({ data: rsvp });
  }),

  listAttendees: asyncHandler(async (req: Request, res: Response) => {
    const { cursor, limit } = req.query as unknown as { cursor?: string; limit?: number };
    const result = await eventsService.listAttendees(req.params.eventId, { cursor, limit });
    res.json({ data: result.items, nextCursor: result.nextCursor });
  }),

  checkIn: asyncHandler(async (req: Request, res: Response) => {
    const checkIn = await eventsService.checkIn(req.params.checkInCode, req.user!.sub);
    res.status(201).json({ data: checkIn });
  }),
};
