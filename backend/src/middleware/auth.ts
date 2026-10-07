import { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import { env } from "../config/env";
import { Errors } from "./errors";
import type { Role } from "@prisma/client";

export interface AccessTokenPayload {
  sub: string; // userId
  role: Role;
  tokenVersion?: number;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      user?: AccessTokenPayload;
    }
  }
}

// Verifies the short-lived access token on every protected request.
// Never trusts a client-supplied user id — identity always comes from the
// verified token signature, not from the request body/query.
export function requireAuth(req: Request, _res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    return next(Errors.unauthorized("Missing or malformed Authorization header"));
  }

  const token = header.slice("Bearer ".length);

  try {
    const payload = jwt.verify(token, env.JWT_ACCESS_SECRET, { algorithms: ["HS256"] }) as AccessTokenPayload;
    req.user = payload;
    return next();
  } catch {
    return next(Errors.unauthorized("Invalid or expired access token"));
  }
}

// Optional auth: attaches req.user if a valid token is present, but never
// blocks the request — used for endpoints that show more data to owners.
export function optionalAuth(req: Request, _res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) return next();

  try {
    req.user = jwt.verify(header.slice("Bearer ".length), env.JWT_ACCESS_SECRET, {
      algorithms: ["HS256"],
    }) as AccessTokenPayload;
  } catch {
    // Ignore invalid tokens on optional routes — treat as anonymous.
  }
  return next();
}

export function requireRole(...roles: Role[]) {
  return (req: Request, _res: Response, next: NextFunction) => {
    if (!req.user) return next(Errors.unauthorized());
    if (!roles.includes(req.user.role)) {
      return next(Errors.forbidden("You do not have permission to perform this action"));
    }
    return next();
  };
}
