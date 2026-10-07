import { z } from "zod";

const currentYear = new Date().getFullYear();

const createVehicleBody = z.object({
  vin: z.string().length(17).optional(),
  make: z.string().min(1).max(60),
  model: z.string().min(1).max(60),
  year: z.number().int().min(1886).max(currentYear + 2),
  trim: z.string().max(60).optional(),
  nickname: z.string().max(60).optional(),
  odometer: z.number().int().min(0).optional(),
  odometerUnit: z.enum(["mi", "km"]).default("mi"),
  isPublic: z.boolean().default(true),
});

const updateVehicleBody = createVehicleBody.partial();

const garageIdParams = z.object({ garageId: z.string().uuid() });
const vehicleIdParams = z.object({ garageId: z.string().uuid(), vehicleId: z.string().uuid() });
const vinParams = z.object({ vin: z.string().length(17) });
const listQuery = z.object({
  cursor: z.string().uuid().optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

const createCommentBody = z.object({
  content: z.string().min(1).max(2000),
});
const updateCommentBody = z.object({
  content: z.string().min(1).max(2000),
});
const commentIdParams = z.object({
  garageId: z.string().uuid(),
  vehicleId: z.string().uuid(),
  commentId: z.string().uuid(),
});

export const createVehicleSchema = { body: createVehicleBody, params: garageIdParams };
export const updateVehicleSchema = { body: updateVehicleBody, params: vehicleIdParams };
export const vehicleIdParamSchema = { params: vehicleIdParams };
export const garageVehiclesParamSchema = { params: garageIdParams, query: listQuery };
export const listVehicleBookmarksSchema = { query: listQuery };
export const vinDecodeParamSchema = { params: vinParams };
export const listVehicleCommentsSchema = { params: vehicleIdParams, query: listQuery };
export const createVehicleCommentSchema = { body: createCommentBody, params: vehicleIdParams };
export const updateVehicleCommentSchema = { body: updateCommentBody, params: commentIdParams };
export const vehicleCommentIdParamSchema = { params: commentIdParams };

const searchQuery = listQuery.extend({
  search: z.string().trim().min(1).max(140).optional(),
});
export const searchVehiclesSchema = { query: searchQuery };

export type CreateVehicleInput = z.infer<typeof createVehicleBody>;
export type UpdateVehicleInput = z.infer<typeof updateVehicleBody>;
