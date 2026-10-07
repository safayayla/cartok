import argon2 from "argon2";
import jwt from "jsonwebtoken";
import crypto from "node:crypto";
import { v4 as uuid } from "uuid";
import { prisma } from "../../config/prisma";
import { env } from "../../config/env";
import { Errors } from "../../middleware/errors";
import type { Role, User } from "@prisma/client";
import type { RegisterInput, LoginInput } from "./auth.schemas";

const REFRESH_TTL_MS = env.REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000;

function hashRefreshToken(token: string) {
  // Refresh tokens are high-entropy random strings (not user-chosen passwords),
  // so a fast, deterministic hash (for DB lookup) is appropriate here; argon2
  // is reserved for passwords where slow hashing matters against guessing.
  return crypto.createHash("sha256").update(token).digest("hex");
}

function signAccessToken(user: Pick<User, "id" | "role">) {
  return jwt.sign({ sub: user.id, role: user.role }, env.JWT_ACCESS_SECRET, {
    expiresIn: env.ACCESS_TOKEN_TTL as jwt.SignOptions["expiresIn"],
    algorithm: "HS256",
  });
}

function generateRefreshTokenValue() {
  return `${uuid()}.${crypto.randomBytes(32).toString("hex")}`;
}

export const authService = {
  async register(input: RegisterInput) {
    const existing = await prisma.user.findFirst({
      where: { OR: [{ email: input.email }, { username: input.username }] },
      select: { id: true },
    });
    if (existing) throw Errors.conflict("Email or username already in use");

    const passwordHash = await argon2.hash(input.password, { type: argon2.argon2id });

    const user = await prisma.user.create({
      data: {
        email: input.email,
        username: input.username,
        passwordHash,
        displayName: input.displayName,
      },
    });

    await prisma.auditLog.create({
      data: { userId: user.id, action: "USER_REGISTERED", entity: "User", entityId: user.id },
    });

    return user;
  },

  async login(input: LoginInput, meta: { ipAddress?: string; userAgent?: string }) {
    const user = await prisma.user.findUnique({ where: { email: input.email } });
    // Constant-shape response whether the email exists or not, to avoid
    // leaking account existence via timing/response differences.
    const dummyHash = "$argon2id$v=19$m=65536,t=3,p=4$c29tZXNhbHQ$c29tZWhhc2g";
    const valid = await argon2.verify(user?.passwordHash ?? dummyHash, input.password).catch(() => false);

    if (!user || !valid) throw Errors.unauthorized("Invalid email or password");
    if (user.isBanned || !user.isActive) throw Errors.forbidden("This account is disabled");

    return this.issueTokenPair(user, meta);
  },

  async issueTokenPair(user: Pick<User, "id" | "role">, meta: { ipAddress?: string; userAgent?: string }) {
    const accessToken = signAccessToken(user);
    const refreshTokenValue = generateRefreshTokenValue();

    await prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: hashRefreshToken(refreshTokenValue),
        expiresAt: new Date(Date.now() + REFRESH_TTL_MS),
        ipAddress: meta.ipAddress,
        userAgent: meta.userAgent,
      },
    });

    return { accessToken, refreshToken: refreshTokenValue };
  },

  // Rotates refresh tokens on every use (one-time-use tokens): the old token
  // is revoked and a brand new one issued. If a revoked token is presented
  // again, that's a strong signal of theft/replay, so we revoke the whole chain.
  //
  // The revoke itself is a single atomic conditional UPDATE (WHERE revokedAt
  // IS NULL) rather than a read-then-later-write. Two concurrent requests
  // racing on the same raw token could otherwise both read revokedAt=null,
  // both pass the check, and both mint a new token pair from one stolen or
  // double-fired token — the atomic claim below means only one caller can
  // ever "win" a given token, full stop.
  async rotateRefreshToken(rawToken: string, meta: { ipAddress?: string; userAgent?: string }) {
    const tokenHash = hashRefreshToken(rawToken);
    const now = new Date();

    const claim = await prisma.refreshToken.updateMany({
      where: { tokenHash, revokedAt: null, expiresAt: { gt: now } },
      data: { revokedAt: now },
    });

    if (claim.count === 0) {
      // The atomic claim failed — figure out why, for reuse-detection and
      // error clarity. This read is purely diagnostic; it grants no access.
      const existing = await prisma.refreshToken.findUnique({ where: { tokenHash } });

      if (existing?.revokedAt) {
        // Reuse of an already-rotated (or already-claimed-concurrently) token
        // is a strong compromise signal — kill every active session for this user.
        await prisma.refreshToken.updateMany({
          where: { userId: existing.userId, revokedAt: null },
          data: { revokedAt: now },
        });
        throw Errors.unauthorized("Refresh token reuse detected; all sessions revoked");
      }
      if (existing && existing.expiresAt <= now) {
        throw Errors.unauthorized("Refresh token expired");
      }
      throw Errors.unauthorized("Invalid refresh token");
    }

    const stored = await prisma.refreshToken.findUnique({ where: { tokenHash } });
    const user = await prisma.user.findUnique({ where: { id: stored!.userId } });
    if (!user || user.isBanned || !user.isActive) throw Errors.forbidden("Account disabled");

    const { accessToken, refreshToken } = await this.issueTokenPair(user, meta);

    await prisma.refreshToken.update({
      where: { id: stored!.id },
      data: { replacedBy: hashRefreshToken(refreshToken) },
    });

    return { accessToken, refreshToken, user };
  },

  async revokeRefreshToken(rawToken: string) {
    const tokenHash = hashRefreshToken(rawToken);
    await prisma.refreshToken.updateMany({
      where: { tokenHash, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  },

  async revokeAllSessions(userId: string) {
    await prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  },

  sanitizeUser(user: User) {
    const { passwordHash: _passwordHash, ...safe } = user;
    return safe;
  },
};

export type { Role };
