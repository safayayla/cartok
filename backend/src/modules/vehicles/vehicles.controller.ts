import { Request, Response } from "express";
import { vehiclesService } from "./vehicles.service";
import { asyncHandler } from "../../middleware/errors";

export const vehiclesController = {
  create: asyncHandler(async (req: Request, res: Response) => {
    const vehicle = await vehiclesService.create(req.params.garageId, req.user!.sub, req.body);
    res.status(201).json({ data: vehicle });
  }),

  list: asyncHandler(async (req: Request, res: Response) => {
    const { cursor, limit } = req.query as unknown as { cursor?: string; limit: number };
    const result = await vehiclesService.listByGarage(req.params.garageId, req.user?.sub, { cursor, limit });
    res.json({ data: result.items, nextCursor: result.nextCursor });
  }),

  getById: asyncHandler(async (req: Request, res: Response) => {
    const vehicle = await vehiclesService.getById(req.params.garageId, req.params.vehicleId, req.user?.sub);
    res.json({ data: vehicle });
  }),

  update: asyncHandler(async (req: Request, res: Response) => {
    const vehicle = await vehiclesService.update(
      req.params.garageId,
      req.params.vehicleId,
      req.user!.sub,
      req.body
    );
    res.json({ data: vehicle });
  }),

  remove: asyncHandler(async (req: Request, res: Response) => {
    await vehiclesService.remove(req.params.garageId, req.params.vehicleId, req.user!.sub);
    res.status(204).send();
  }),

  decodeVin: asyncHandler(async (req: Request, res: Response) => {
    const decoded = await vehiclesService.decodeVinPreview(req.params.vin);
    res.json({ data: decoded });
  }),

  like: asyncHandler(async (req: Request, res: Response) => {
    await vehiclesService.like(req.params.garageId, req.params.vehicleId, req.user!.sub);
    res.status(204).send();
  }),

  unlike: asyncHandler(async (req: Request, res: Response) => {
    await vehiclesService.unlike(req.params.garageId, req.params.vehicleId, req.user!.sub);
    res.status(204).send();
  }),

  listComments: asyncHandler(async (req: Request, res: Response) => {
    const { cursor, limit } = req.query as unknown as { cursor?: string; limit?: number };
    const result = await vehiclesService.listComments(
      req.params.garageId,
      req.params.vehicleId,
      req.user?.sub,
      { cursor, limit }
    );
    res.json({ data: result.items, nextCursor: result.nextCursor });
  }),

  createComment: asyncHandler(async (req: Request, res: Response) => {
    const comment = await vehiclesService.createComment(
      req.params.garageId,
      req.params.vehicleId,
      req.user!.sub,
      req.body.content
    );
    res.status(201).json({ data: comment });
  }),

  updateComment: asyncHandler(async (req: Request, res: Response) => {
    const comment = await vehiclesService.updateComment(req.params.commentId, req.user!.sub, req.body.content);
    res.json({ data: comment });
  }),

  deleteComment: asyncHandler(async (req: Request, res: Response) => {
    const isModerator = req.user!.role === "MODERATOR" || req.user!.role === "ADMIN";
    await vehiclesService.deleteComment(req.params.commentId, req.user!.sub, isModerator);
    res.status(204).send();
  }),

  bookmark: asyncHandler(async (req: Request, res: Response) => {
    await vehiclesService.bookmark(req.params.garageId, req.params.vehicleId, req.user!.sub);
    res.status(204).send();
  }),

  unbookmark: asyncHandler(async (req: Request, res: Response) => {
    await vehiclesService.unbookmark(req.params.garageId, req.params.vehicleId, req.user!.sub);
    res.status(204).send();
  }),

  listBookmarks: asyncHandler(async (req: Request, res: Response) => {
    const { cursor, limit } = req.query as unknown as { cursor?: string; limit: number };
    const result = await vehiclesService.listBookmarkedVehicles(req.user!.sub, { cursor, limit });
    res.json({ data: result.items, nextCursor: result.nextCursor });
  }),

  search: asyncHandler(async (req: Request, res: Response) => {
    const { search, cursor, limit } = req.query as unknown as { search?: string; cursor?: string; limit: number };
    const result = await vehiclesService.searchPublic({ search, cursor, limit });
    res.json({ data: result.items, nextCursor: result.nextCursor });
  }),
};
