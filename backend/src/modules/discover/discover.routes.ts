import { Router } from "express";
import { discoverController } from "./discover.controller";
import { optionalAuth } from "../../middleware/auth";
import { validate } from "../../middleware/validate";
import { getFeedSchema } from "./discover.schemas";

export const discoverRouter = Router();

// optionalAuth: the feed works for anonymous browsing, but a logged-in
// viewer gets the follow-boost personalization on top.
discoverRouter.get("/", optionalAuth, validate(getFeedSchema), discoverController.getFeed);
