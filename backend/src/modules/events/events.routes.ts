import { Router } from "express";
import { eventsController } from "./events.controller";
import { requireAuth, optionalAuth } from "../../middleware/auth";
import { validate } from "../../middleware/validate";
import {
  createEventSchema,
  updateEventSchema,
  eventIdParamSchema,
  listEventsSchema,
  rsvpSchema,
  checkInParamSchema,
} from "./events.schemas";

export const eventsRouter = Router();

eventsRouter.post("/", requireAuth, validate(createEventSchema), eventsController.create);
eventsRouter.get("/", validate(listEventsSchema), eventsController.list);
// Static path registered before the dynamic /:eventId path so "check-in" is
// never swallowed by the :eventId param matcher.
eventsRouter.post(
  "/check-in/:checkInCode",
  requireAuth,
  validate(checkInParamSchema),
  eventsController.checkIn
);
eventsRouter.get("/:eventId", optionalAuth, validate(eventIdParamSchema), eventsController.getById);
eventsRouter.patch("/:eventId", requireAuth, validate(updateEventSchema), eventsController.update);
eventsRouter.post("/:eventId/cancel", requireAuth, validate(eventIdParamSchema), eventsController.cancel);
eventsRouter.post("/:eventId/rsvp", requireAuth, validate(rsvpSchema), eventsController.rsvp);
eventsRouter.get(
  "/:eventId/attendees",
  requireAuth,
  validate(eventIdParamSchema),
  eventsController.listAttendees
);
