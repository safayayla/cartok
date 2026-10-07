import { createClient } from "redis";
import { env } from "./env";
import { logger } from "./logger";

export const redis = createClient({ url: env.REDIS_URL });

redis.on("error", (err) => logger.error({ err }, "Redis client error"));

export async function connectRedis() {
  if (!redis.isOpen) {
    await redis.connect();
    logger.info("Redis connected");
  }
}
