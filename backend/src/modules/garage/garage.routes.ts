import { Router } from "express";
import { garageController } from "./garage.controller";
import { requireAuth, optionalAuth } from "../../middleware/auth";
import { validate } from "../../middleware/validate";
import { createGarageSchema, updateGarageSchema, garageIdParamSchema, listGaragesSchema, browseGaragesSchema } from "./garage.schemas";
import { vehiclesRouter } from "../vehicles/vehicles.routes";
import { vehiclesController } from "../vehicles/vehicles.controller";
import { listVehicleBookmarksSchema } from "../vehicles/vehicles.schemas";

export const garageRouter = Router();

garageRouter.post("/", requireAuth, validate(createGarageSchema), garageController.create);
garageRouter.get("/", validate(browseGaragesSchema), garageController.browse);
garageRouter.get("/mine", requireAuth, validate(listGaragesSchema), garageController.myGarages);

// Cross-garage: "vehicles I bookmarked," not scoped to one garage — must be
// registered before /:garageId or "vehicle-bookmarks" would be mismatched
// as a garageId and rejected by UUID validation instead of reaching here.
garageRouter.get(
  "/vehicle-bookmarks",
  requireAuth,
  validate(listVehicleBookmarksSchema),
  vehiclesController.listBookmarks
);

garageRouter.get("/:garageId", optionalAuth, validate(garageIdParamSchema), garageController.getById);
garageRouter.patch("/:garageId", requireAuth, validate(updateGarageSchema), garageController.update);
garageRouter.delete("/:garageId", requireAuth, validate(garageIdParamSchema), garageController.remove);
garageRouter.post("/:garageId/follow", requireAuth, validate(garageIdParamSchema), garageController.follow);
garageRouter.delete("/:garageId/follow", requireAuth, validate(garageIdParamSchema), garageController.unfollow);

// Vehicles are nested under a garage (a vehicle always belongs to exactly one garage).
garageRouter.use("/:garageId/vehicles", vehiclesRouter);
