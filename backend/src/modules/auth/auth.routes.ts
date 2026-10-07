import { Router } from "express";
import { authController } from "./auth.controller";
import { validate } from "../../middleware/validate";
import { registerSchema, loginSchema, refreshSchema } from "./auth.schemas";
import { authRateLimiter } from "../../middleware/rateLimit";
import { requireAuth } from "../../middleware/auth";

export const authRouter = Router();

authRouter.post("/register", authRateLimiter, validate(registerSchema), authController.register);
authRouter.post("/login", authRateLimiter, validate(loginSchema), authController.login);
authRouter.post("/refresh", authRateLimiter, validate(refreshSchema), authController.refresh);
authRouter.post("/logout", validate(refreshSchema), authController.logout);
authRouter.post("/logout-all", requireAuth, authController.logoutAll);
