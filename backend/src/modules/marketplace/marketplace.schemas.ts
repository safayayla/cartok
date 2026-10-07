import { z } from "zod";

const listingTypeEnum = z.enum([
  "CAR",
  "MOTORCYCLE",
  "PART",
  "ACCESSORY",
  "WHEELS",
  "TIRES",
  "TOOLS",
  "ELECTRONICS",
  "GARAGE_EQUIPMENT",
  "TRANSPORT",
  "WANTED",
]);
const listingConditionEnum = z.enum(["NEW", "USED", "FOR_PARTS"]);
const listingStatusEnum = z.enum(["ACTIVE", "SOLD", "DRAFT", "REMOVED"]);

const createListingBody = z.object({
  type: listingTypeEnum,
  title: z.string().min(3).max(140),
  description: z.string().min(1).max(5000),
  priceCents: z.number().int().min(0).max(1_000_000_000), // up to $10M, generous ceiling not a real limit
  currency: z.string().length(3).default("USD"),
  condition: listingConditionEnum.optional(),
  location: z.string().max(200).optional(),
  vehicleId: z.string().uuid().optional(),
  imageUrls: z.array(z.string().url()).max(20).default([]),
});

const updateListingBody = z.object({
  title: z.string().min(3).max(140).optional(),
  description: z.string().min(1).max(5000).optional(),
  priceCents: z.number().int().min(0).max(1_000_000_000).optional(),
  condition: listingConditionEnum.optional(),
  location: z.string().max(200).optional(),
  imageUrls: z.array(z.string().url()).max(20).optional(),
});

const updateStatusBody = z.object({ status: listingStatusEnum });

const listingIdParams = z.object({ listingId: z.string().uuid() });

const listListingsQuery = z.object({
  type: listingTypeEnum.optional(),
  sellerId: z.string().uuid().optional(),
  minPriceCents: z.coerce.number().int().min(0).optional(),
  maxPriceCents: z.coerce.number().int().min(0).optional(),
  search: z.string().max(140).optional(),
  cursor: z.string().uuid().optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

export const createListingSchema = { body: createListingBody };
export const updateListingSchema = { body: updateListingBody, params: listingIdParams };
export const updateStatusSchema = { body: updateStatusBody, params: listingIdParams };
export const listingIdParamSchema = { params: listingIdParams };
export const listListingsSchema = { query: listListingsQuery };

export type CreateListingInput = z.infer<typeof createListingBody>;
export type UpdateListingInput = z.infer<typeof updateListingBody>;
