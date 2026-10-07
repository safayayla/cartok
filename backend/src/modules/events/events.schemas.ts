import { z } from "zod";

const eventTypeEnum = z.enum(["CARS_AND_COFFEE", "DRIVE_TOGETHER", "MEETUP", "TRACK_DAY", "OTHER"]);
const rsvpStatusEnum = z.enum(["GOING", "INTERESTED", "NOT_GOING"]);

const createEventBody = z
  .object({
    type: eventTypeEnum,
    title: z.string().min(1).max(120),
    description: z.string().max(2000).optional(),
    locationName: z.string().min(1).max(200),
    latitude: z.number().min(-90).max(90).optional(),
    longitude: z.number().min(-180).max(180).optional(),
    startTime: z.coerce.date(),
    endTime: z.coerce.date().optional(),
    capacity: z.number().int().min(1).max(100_000).optional(),
  })
  .superRefine((data, ctx) => {
    if (data.endTime && data.endTime <= data.startTime) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, message: "endTime must be after startTime", path: ["endTime"] });
    }
    if (data.startTime <= new Date(Date.now() - 5 * 60 * 1000)) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, message: "startTime must be in the future", path: ["startTime"] });
    }
  });

const updateEventBody = z.object({
  title: z.string().min(1).max(120).optional(),
  description: z.string().max(2000).optional(),
  locationName: z.string().min(1).max(200).optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  startTime: z.coerce.date().optional(),
  endTime: z.coerce.date().optional(),
  capacity: z.number().int().min(1).max(100_000).optional(),
});

const eventIdParams = z.object({ eventId: z.string().uuid() });
const checkInCodeParams = z.object({ checkInCode: z.string().min(10).max(64) });

const listEventsQuery = z.object({
  type: eventTypeEnum.optional(),
  cursor: z.string().uuid().optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

const rsvpBody = z.object({ status: rsvpStatusEnum });

export const createEventSchema = { body: createEventBody };
export const updateEventSchema = { body: updateEventBody, params: eventIdParams };
export const eventIdParamSchema = { params: eventIdParams };
export const listEventsSchema = { query: listEventsQuery };
export const rsvpSchema = { body: rsvpBody, params: eventIdParams };
export const checkInParamSchema = { params: checkInCodeParams };

export type CreateEventInput = z.infer<typeof createEventBody>;
export type UpdateEventInput = z.infer<typeof updateEventBody>;
