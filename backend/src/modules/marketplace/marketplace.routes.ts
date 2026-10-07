import { Router } from "express";
import { marketplaceController } from "./marketplace.controller";
import { requireAuth, optionalAuth } from "../../middleware/auth";
import { validate } from "../../middleware/validate";
import {
  createListingSchema,
  updateListingSchema,
  updateStatusSchema,
  listingIdParamSchema,
  listListingsSchema,
} from "./marketplace.schemas";

export const marketplaceRouter = Router();

marketplaceRouter.post("/", requireAuth, validate(createListingSchema), marketplaceController.create);
marketplaceRouter.get("/", validate(listListingsSchema), marketplaceController.list);
// Static paths registered before the dynamic /:listingId path.
marketplaceRouter.get("/mine", requireAuth, marketplaceController.listMine);
marketplaceRouter.get("/favorites", requireAuth, marketplaceController.listFavorites);

marketplaceRouter.get(
  "/:listingId",
  optionalAuth,
  validate(listingIdParamSchema),
  marketplaceController.getById
);
marketplaceRouter.patch(
  "/:listingId",
  requireAuth,
  validate(updateListingSchema),
  marketplaceController.update
);
marketplaceRouter.patch(
  "/:listingId/status",
  requireAuth,
  validate(updateStatusSchema),
  marketplaceController.updateStatus
);
marketplaceRouter.post(
  "/:listingId/favorite",
  requireAuth,
  validate(listingIdParamSchema),
  marketplaceController.favorite
);
marketplaceRouter.delete(
  "/:listingId/favorite",
  requireAuth,
  validate(listingIdParamSchema),
  marketplaceController.unfavorite
);
