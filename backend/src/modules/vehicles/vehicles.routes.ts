import { Router } from "express";
import { vehiclesController } from "./vehicles.controller";
import { requireAuth, optionalAuth } from "../../middleware/auth";
import { validate } from "../../middleware/validate";
import {
  createVehicleSchema,
  updateVehicleSchema,
  vehicleIdParamSchema,
  garageVehiclesParamSchema,
  listVehicleCommentsSchema,
  createVehicleCommentSchema,
  updateVehicleCommentSchema,
  vehicleCommentIdParamSchema,
  searchVehiclesSchema,
} from "./vehicles.schemas";

// mergeParams: true is required to read :garageId from the parent router
// when this router is mounted at /garages/:garageId/vehicles.
export const vehiclesRouter = Router({ mergeParams: true });

vehiclesRouter.post("/", requireAuth, validate(createVehicleSchema), vehiclesController.create);
vehiclesRouter.get("/", optionalAuth, validate(garageVehiclesParamSchema), vehiclesController.list);
vehiclesRouter.get("/:vehicleId", optionalAuth, validate(vehicleIdParamSchema), vehiclesController.getById);
vehiclesRouter.patch("/:vehicleId", requireAuth, validate(updateVehicleSchema), vehiclesController.update);
vehiclesRouter.delete("/:vehicleId", requireAuth, validate(vehicleIdParamSchema), vehiclesController.remove);

vehiclesRouter.post("/:vehicleId/like", requireAuth, validate(vehicleIdParamSchema), vehiclesController.like);
vehiclesRouter.delete("/:vehicleId/like", requireAuth, validate(vehicleIdParamSchema), vehiclesController.unlike);

vehiclesRouter.get(
  "/:vehicleId/comments",
  optionalAuth,
  validate(listVehicleCommentsSchema),
  vehiclesController.listComments
);
vehiclesRouter.post(
  "/:vehicleId/comments",
  requireAuth,
  validate(createVehicleCommentSchema),
  vehiclesController.createComment
);
vehiclesRouter.patch(
  "/:vehicleId/comments/:commentId",
  requireAuth,
  validate(updateVehicleCommentSchema),
  vehiclesController.updateComment
);
vehiclesRouter.delete(
  "/:vehicleId/comments/:commentId",
  requireAuth,
  validate(vehicleCommentIdParamSchema),
  vehiclesController.deleteComment
);

vehiclesRouter.post(
  "/:vehicleId/bookmark",
  requireAuth,
  validate(vehicleIdParamSchema),
  vehiclesController.bookmark
);
vehiclesRouter.delete(
  "/:vehicleId/bookmark",
  requireAuth,
  validate(vehicleIdParamSchema),
  vehiclesController.unbookmark
);

// Not nested under a garage — this searches public vehicles across every
// garage, so it can't use the mergeParams(:garageId) router above. Same
// module, same controller/service, just mounted at a different top-level
// path (see app.ts: `/api/v1/vehicles`) rather than under
// `/garages/:garageId/vehicles`.
export const vehiclesSearchRouter = Router();
vehiclesSearchRouter.get("/search", validate(searchVehiclesSchema), vehiclesController.search);
