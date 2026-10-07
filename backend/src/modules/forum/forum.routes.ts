import { Router } from "express";
import { forumController } from "./forum.controller";
import { requireAuth, requireRole, optionalAuth } from "../../middleware/auth";
import { validate } from "../../middleware/validate";
import {
  createCategorySchema,
  createThreadSchema,
  listThreadsSchema,
  threadIdParamSchema,
  createPostSchema,
  postIdParamSchema,
  updatePostSchema,
  voteSchema,
  listBookmarksSchema,
} from "./forum.schemas";

export const forumRouter = Router();

// Categories
forumRouter.get("/categories", forumController.listCategories);
forumRouter.post(
  "/categories",
  requireAuth,
  requireRole("ADMIN", "MODERATOR"),
  validate(createCategorySchema),
  forumController.createCategory
);

// Threads
forumRouter.post(
  "/categories/:categoryId/threads",
  requireAuth,
  validate(createThreadSchema),
  forumController.createThread
);
forumRouter.get(
  "/categories/:categoryId/threads",
  validate(listThreadsSchema),
  forumController.listThreads
);

// Bookmarks — registered before /threads/:threadId so "bookmarks" is never
// mismatched as a threadId (it would fail UUID validation and 400 instead
// of falling through to this route if registered after).
forumRouter.get("/threads/bookmarks", requireAuth, validate(listBookmarksSchema), forumController.listBookmarks);
forumRouter.post(
  "/threads/:threadId/bookmark",
  requireAuth,
  validate(threadIdParamSchema),
  forumController.bookmark
);
forumRouter.delete(
  "/threads/:threadId/bookmark",
  requireAuth,
  validate(threadIdParamSchema),
  forumController.unbookmark
);

forumRouter.get("/threads/:threadId", optionalAuth, validate(threadIdParamSchema), forumController.getThread);

// Posts
forumRouter.post(
  "/threads/:threadId/posts",
  requireAuth,
  validate(createPostSchema),
  forumController.createPost
);
forumRouter.patch(
  "/threads/:threadId/posts/:postId",
  requireAuth,
  validate(updatePostSchema),
  forumController.updatePost
);
forumRouter.delete(
  "/threads/:threadId/posts/:postId",
  requireAuth,
  validate(postIdParamSchema),
  forumController.deletePost
);

// Votes
forumRouter.post(
  "/threads/:threadId/posts/:postId/vote",
  requireAuth,
  validate(voteSchema),
  forumController.vote
);
forumRouter.delete(
  "/threads/:threadId/posts/:postId/vote",
  requireAuth,
  validate(postIdParamSchema),
  forumController.removeVote
);
