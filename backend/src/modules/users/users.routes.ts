import { Router } from "express";
import { usersController } from "./users.controller";
import { requireAuth, optionalAuth } from "../../middleware/auth";
import { validate } from "../../middleware/validate";
import { updateProfileSchema, usernameParamSchema, listFollowSchema, searchUsersSchema } from "./users.schemas";

export const usersRouter = Router();

usersRouter.get("/me", requireAuth, usersController.me);
usersRouter.patch("/me", requireAuth, validate(updateProfileSchema), usersController.updateMe);
usersRouter.get("/search", validate(searchUsersSchema), usersController.search);
usersRouter.get("/:username", optionalAuth, validate(usernameParamSchema), usersController.getByUsername);
usersRouter.post("/:username/follow", requireAuth, validate(usernameParamSchema), usersController.follow);
usersRouter.delete("/:username/follow", requireAuth, validate(usernameParamSchema), usersController.unfollow);
usersRouter.get("/:username/followers", validate(listFollowSchema), usersController.listFollowers);
usersRouter.get("/:username/following", validate(listFollowSchema), usersController.listFollowing);
