import { Request, Response } from "express";
import { authService } from "./auth.service";
import { asyncHandler, Errors } from "../../middleware/errors";
import { env, isProd } from "../../config/env";

const REFRESH_COOKIE = "cartok_refresh";

function refreshCookieOptions() {
  return {
    httpOnly: true,
    secure: isProd,
    sameSite: "strict" as const,
    domain: env.COOKIE_DOMAIN,
    path: "/api/v1/auth",
    maxAge: env.REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000,
  };
}

function requestMeta(req: Request) {
  return { ipAddress: req.ip, userAgent: req.headers["user-agent"] };
}

export const authController = {
  register: asyncHandler(async (req: Request, res: Response) => {
    const user = await authService.register(req.body);
    res.status(201).json({ data: authService.sanitizeUser(user) });
  }),

  login: asyncHandler(async (req: Request, res: Response) => {
    const { accessToken, refreshToken } = await authService.login(req.body, requestMeta(req));
    res.cookie(REFRESH_COOKIE, refreshToken, refreshCookieOptions());
    res.json({ data: { accessToken } });
  }),

  refresh: asyncHandler(async (req: Request, res: Response) => {
    const rawToken = req.cookies?.[REFRESH_COOKIE] ?? req.body.refreshToken;
    if (!rawToken) throw Errors.unauthorized("No refresh token provided");

    const { accessToken, refreshToken } = await authService.rotateRefreshToken(rawToken, requestMeta(req));
    res.cookie(REFRESH_COOKIE, refreshToken, refreshCookieOptions());
    res.json({ data: { accessToken } });
  }),

  logout: asyncHandler(async (req: Request, res: Response) => {
    const rawToken = req.cookies?.[REFRESH_COOKIE] ?? req.body.refreshToken;
    if (rawToken) await authService.revokeRefreshToken(rawToken);
    res.clearCookie(REFRESH_COOKIE, { path: "/api/v1/auth" });
    res.status(204).send();
  }),

  logoutAll: asyncHandler(async (req: Request, res: Response) => {
    await authService.revokeAllSessions(req.user!.sub);
    res.clearCookie(REFRESH_COOKIE, { path: "/api/v1/auth" });
    res.status(204).send();
  }),
};
