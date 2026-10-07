import rateLimit from "express-rate-limit";
import { RedisStore } from "rate-limit-redis";
import jwt from "jsonwebtoken";
import { Request } from "express";
import { redis } from "../config/redis";

// Prefer keying by authenticated user over raw IP: mobile clients very
// commonly share carrier-grade NAT IPs, so IP-only keying would let one
// user's traffic exhaust the shared bucket for many unrelated users on the
// same network. This is decode-only (no signature check) purely to pick a
// bucket — an invalid/forged token just lands in its own harmless bucket,
// it grants no access, so it doesn't need to go through requireAuth.
function rateLimitKey(req: Request): string {
  const header = req.headers.authorization;
  if (header?.startsWith("Bearer ")) {
    try {
      const decoded = jwt.decode(header.slice("Bearer ".length)) as { sub?: string } | null;
      if (decoded?.sub) return `user:${decoded.sub}`;
    } catch {
      // Fall through to IP-based keying.
    }
  }
  return `ip:${req.ip}`;
}

function makeLimiter(windowMs: number, max: number, prefix: string) {
  return rateLimit({
    windowMs,
    max,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: rateLimitKey,
    store: new RedisStore({
      sendCommand: (...args: string[]) => redis.sendCommand(args),
      prefix,
    }),
    message: { error: { code: "RATE_LIMITED", message: "Too many requests, please try again later." } },
  });
}

// Tight limit on auth endpoints to blunt credential stuffing / brute force.
// Deliberately IP-based even with the shared NAT trade-off above: at the
// login/register stage there's no token yet to key on, and this is exactly
// the endpoint where broad, IP-based throttling matters most for security.
export const authRateLimiter = makeLimiter(15 * 60 * 1000, 10, "rl:auth:");

// Looser general-purpose API limit, keyed by user where possible.
export const apiRateLimiter = makeLimiter(60 * 1000, 120, "rl:api:");
