import { PrismaClient } from "@prisma/client";
import { isProd } from "./env";

// Single shared Prisma instance (avoids exhausting Postgres connections
// under hot-reload in dev, and under serverless-style scaling in prod).
declare global {
  // eslint-disable-next-line no-var
  var __prisma__: PrismaClient | undefined;
}

export const prisma =
  global.__prisma__ ??
  new PrismaClient({
    log: isProd ? ["error", "warn"] : ["error", "warn", "query"],
  });

if (!isProd) {
  global.__prisma__ = prisma;
}
