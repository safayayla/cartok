import { NextFunction, Request, Response } from "express";
import { ZodError } from "zod";
import { Prisma } from "@prisma/client";
import { logger } from "../config/logger";
import { isProd } from "../config/env";

export class AppError extends Error {
  constructor(
    public statusCode: number,
    public code: string,
    message: string,
    public details?: unknown
  ) {
    super(message);
    this.name = "AppError";
  }
}

export const Errors = {
  badRequest: (msg = "Bad request", details?: unknown) => new AppError(400, "BAD_REQUEST", msg, details),
  unauthorized: (msg = "Unauthorized") => new AppError(401, "UNAUTHORIZED", msg),
  forbidden: (msg = "Forbidden") => new AppError(403, "FORBIDDEN", msg),
  notFound: (msg = "Resource not found") => new AppError(404, "NOT_FOUND", msg),
  conflict: (msg = "Conflict") => new AppError(409, "CONFLICT", msg),
  tooManyRequests: (msg = "Too many requests") => new AppError(429, "RATE_LIMITED", msg),
  internal: (msg = "Internal server error") => new AppError(500, "INTERNAL_ERROR", msg),
};

// Catches every thrown/rejected error in one place so every route gets
// consistent, safe (non-leaky) error responses without repeating try/catch boilerplate.
export function errorHandler(err: unknown, req: Request, res: Response, _next: NextFunction) {
  const requestId = (req as Request & { id?: string }).id;

  if (err instanceof AppError) {
    if (err.statusCode >= 500) {
      logger.error({ err, requestId }, err.message);
      // Even a "known" AppError shouldn't leak internal detail in prod once
      // it's a 5xx — only 4xx AppErrors are meant to be safe, user-facing
      // text by construction. This mirrors the hiding the generic
      // unhandled-error path below already does, so there's no gap where a
      // future `Errors.internal(someInternalDetail)` call quietly bypasses it.
      const message = isProd ? "Something went wrong" : err.message;
      return res.status(err.statusCode).json({ error: { code: err.code, message, requestId } });
    }
    return res.status(err.statusCode).json({
      error: { code: err.code, message: err.message, details: err.details, requestId },
    });
  }

  if (err instanceof ZodError) {
    return res.status(400).json({
      error: { code: "VALIDATION_ERROR", message: "Validation failed", details: err.flatten(), requestId },
    });
  }

  if (Prisma.PrismaClientKnownRequestError && err instanceof Prisma.PrismaClientKnownRequestError) {
    if (err.code === "P2002") {
      return res.status(409).json({
        error: { code: "CONFLICT", message: "A record with these unique fields already exists", requestId },
      });
    }
    if (err.code === "P2025") {
      return res.status(404).json({ error: { code: "NOT_FOUND", message: "Record not found", requestId } });
    }
  }

  logger.error({ err, requestId }, "Unhandled error");
  return res.status(500).json({
    error: {
      code: "INTERNAL_ERROR",
      message: isProd ? "Something went wrong" : String(err instanceof Error ? err.message : err),
      requestId,
    },
  });
}

export function notFoundHandler(req: Request, res: Response) {
  res.status(404).json({ error: { code: "NOT_FOUND", message: `Route ${req.method} ${req.path} not found` } });
}

// Wraps async route handlers so rejected promises reach errorHandler
// instead of crashing the process or hanging the request.
export function asyncHandler<T extends (req: Request, res: Response, next: NextFunction) => Promise<unknown>>(
  fn: T
) {
  return (req: Request, res: Response, next: NextFunction) => {
    fn(req, res, next).catch(next);
  };
}
