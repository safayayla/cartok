import { Router } from "express";
import { validate } from "../../middleware/validate";
import { vinDecodeParamSchema } from "../vehicles/vehicles.schemas";
import { vehiclesController } from "../vehicles/vehicles.controller";
import { apiRateLimiter } from "../../middleware/rateLimit";

export const vinRouter = Router();

// Standalone decode-before-you-own-a-garage endpoint, e.g. for a
// "check a VIN before adding it" step in the mobile add-vehicle flow.
vinRouter.get("/:vin", apiRateLimiter, validate(vinDecodeParamSchema), vehiclesController.decodeVin);
