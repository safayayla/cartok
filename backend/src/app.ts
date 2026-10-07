import express from "express";
import helmet from "helmet";
import cors from "cors";
import cookieParser from "cookie-parser";
import pinoHttp from "pino-http";
import { randomUUID } from "node:crypto";
import { env } from "./config/env";
import { logger } from "./config/logger";
import { errorHandler, notFoundHandler } from "./middleware/errors";
import { apiRateLimiter } from "./middleware/rateLimit";
import { authRouter } from "./modules/auth/auth.routes";
import { usersRouter } from "./modules/users/users.routes";
import { garageRouter } from "./modules/garage/garage.routes";
import { vinRouter } from "./modules/vin/vin.routes";
import { forumRouter } from "./modules/forum/forum.routes";
import { notificationsRouter } from "./modules/notifications/notifications.routes";
import { eventsRouter } from "./modules/events/events.routes";
import { marketplaceRouter } from "./modules/marketplace/marketplace.routes";
import { discoverRouter } from "./modules/discover/discover.routes";
import { messagingRouter } from "./modules/messaging/messaging.routes";

export function createApp() {
  const app = express();

  // Trust the first proxy hop (load balancer/ingress) so req.ip and secure
  // cookies behave correctly in production behind e.g. an ALB or nginx.
  app.set("trust proxy", 1);

  app.use(
    helmet({
      contentSecurityPolicy: { useDefaults: true },
      crossOriginResourcePolicy: { policy: "same-site" },
    })
  );

  app.use(
    cors({
      origin: env.CORS_ORIGINS.split(",").map((o) => o.trim()),
      credentials: true,
    })
  );

  app.use(express.json({ limit: "1mb" }));
  app.use(cookieParser());

  app.use((req, _res, next) => {
    (req as express.Request & { id: string }).id = randomUUID();
    next();
  });

  app.use(
    pinoHttp({
      logger,
      genReqId: (req) => (req as express.Request & { id: string }).id,
      customLogLevel: (_req, res, err) => (err || res.statusCode >= 500 ? "error" : res.statusCode >= 400 ? "warn" : "info"),
    })
  );

  app.get("/health", (_req, res) => res.json({ status: "ok", timestamp: new Date().toISOString() }));
  app.get("/ready", (_req, res) => res.json({ status: "ready" }));

  app.use("/api/v1", apiRateLimiter);
  app.use("/api/v1/auth", authRouter);
  app.use("/api/v1/users", usersRouter);
  app.use("/api/v1/garages", garageRouter);
  app.use("/api/v1/vin", vinRouter);
  app.use("/api/v1/forum", forumRouter);
  app.use("/api/v1/notifications", notificationsRouter);
  app.use("/api/v1/events", eventsRouter);
  app.use("/api/v1/discover", discoverRouter);
  app.use("/api/v1/messaging", messagingRouter);
  app.use("/api/v1/marketplace", marketplaceRouter);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
