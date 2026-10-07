import { Request, Response } from "express";
import { usersService } from "./users.service";
import { authService } from "../auth/auth.service";
import { asyncHandler } from "../../middleware/errors";

export const usersController = {
  me: asyncHandler(async (req: Request, res: Response) => {
    const user = await usersService.getById(req.user!.sub);
    res.json({ data: authService.sanitizeUser(user) });
  }),

  updateMe: asyncHandler(async (req: Request, res: Response) => {
    const user = await usersService.updateProfile(req.user!.sub, req.body);
    res.json({ data: authService.sanitizeUser(user) });
  }),

  search: asyncHandler(async (req: Request, res: Response) => {
    const { q, limit } = req.query as unknown as { q: string; limit: number };
    const users = await usersService.search(q, limit);
    res.json({ data: users });
  }),

  getByUsername: asyncHandler(async (req: Request, res: Response) => {
    const { user, followerCount, followingCount, isFollowedByMe } = await usersService.getByUsername(
      req.params.username,
      req.user?.sub
    );
    // Public profile view: expose only public-safe fields.
    res.json({
      data: {
        id: user.id,
        username: user.username,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        bio: user.bio,
        verification: user.verification,
        createdAt: user.createdAt,
        followerCount,
        followingCount,
        isFollowedByMe,
      },
    });
  }),

  follow: asyncHandler(async (req: Request, res: Response) => {
    await usersService.follow(req.user!.sub, req.params.username);
    res.status(204).send();
  }),

  unfollow: asyncHandler(async (req: Request, res: Response) => {
    await usersService.unfollow(req.user!.sub, req.params.username);
    res.status(204).send();
  }),

  listFollowers: asyncHandler(async (req: Request, res: Response) => {
    const { cursor, limit } = req.query as unknown as { cursor?: string; limit: number };
    const result = await usersService.listFollowers(req.params.username, { cursor, limit });
    res.json({ data: result.items, nextCursor: result.nextCursor });
  }),

  listFollowing: asyncHandler(async (req: Request, res: Response) => {
    const { cursor, limit } = req.query as unknown as { cursor?: string; limit: number };
    const result = await usersService.listFollowing(req.params.username, { cursor, limit });
    res.json({ data: result.items, nextCursor: result.nextCursor });
  }),
};
