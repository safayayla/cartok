import { Request, Response } from "express";
import { forumService } from "./forum.service";
import { asyncHandler } from "../../middleware/errors";

export const forumController = {
  listCategories: asyncHandler(async (_req: Request, res: Response) => {
    const categories = await forumService.listCategories();
    res.json({ data: categories });
  }),

  createCategory: asyncHandler(async (req: Request, res: Response) => {
    const category = await forumService.createCategory(req.body);
    res.status(201).json({ data: category });
  }),

  createThread: asyncHandler(async (req: Request, res: Response) => {
    const thread = await forumService.createThread(req.params.categoryId, req.user!.sub, req.body);
    res.status(201).json({ data: thread });
  }),

  listThreads: asyncHandler(async (req: Request, res: Response) => {
    const { cursor, limit } = req.query as unknown as { cursor?: string; limit: number };
    const result = await forumService.listThreads(req.params.categoryId, { cursor, limit });
    res.json({ data: result.items, nextCursor: result.nextCursor });
  }),

  getThread: asyncHandler(async (req: Request, res: Response) => {
    const thread = await forumService.getThread(req.params.threadId, req.user?.sub);
    const posts = await forumService.listPosts(req.params.threadId);
    res.json({ data: { ...thread, posts } });
  }),

  bookmark: asyncHandler(async (req: Request, res: Response) => {
    await forumService.bookmark(req.params.threadId, req.user!.sub);
    res.status(204).send();
  }),

  unbookmark: asyncHandler(async (req: Request, res: Response) => {
    await forumService.unbookmark(req.params.threadId, req.user!.sub);
    res.status(204).send();
  }),

  listBookmarks: asyncHandler(async (req: Request, res: Response) => {
    const { cursor, limit } = req.query as unknown as { cursor?: string; limit: number };
    const result = await forumService.listBookmarkedThreads(req.user!.sub, { cursor, limit });
    res.json({ data: result.items, nextCursor: result.nextCursor });
  }),

  createPost: asyncHandler(async (req: Request, res: Response) => {
    const post = await forumService.createPost(req.params.threadId, req.user!.sub, req.body);
    res.status(201).json({ data: post });
  }),

  updatePost: asyncHandler(async (req: Request, res: Response) => {
    const post = await forumService.updatePost(req.params.postId, req.user!.sub, req.body.content);
    res.json({ data: post });
  }),

  deletePost: asyncHandler(async (req: Request, res: Response) => {
    const isModerator = req.user!.role === "MODERATOR" || req.user!.role === "ADMIN";
    await forumService.deletePost(req.params.postId, req.user!.sub, isModerator);
    res.status(204).send();
  }),

  vote: asyncHandler(async (req: Request, res: Response) => {
    const vote = await forumService.vote(req.params.postId, req.user!.sub, req.body.value);
    res.json({ data: vote });
  }),

  removeVote: asyncHandler(async (req: Request, res: Response) => {
    await forumService.removeVote(req.params.postId, req.user!.sub);
    res.status(204).send();
  }),
};
