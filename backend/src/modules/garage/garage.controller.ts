import { Request, Response } from "express";
import { garageService } from "./garage.service";
import { asyncHandler } from "../../middleware/errors";

export const garageController = {
  create: asyncHandler(async (req: Request, res: Response) => {
    const garage = await garageService.create(req.user!.sub, req.body);
    res.status(201).json({ data: garage });
  }),

  browse: asyncHandler(async (req: Request, res: Response) => {
    const { search, cursor, limit } = req.query as unknown as { search?: string; cursor?: string; limit: number };
    const result = await garageService.browse({ search, cursor, limit });
    res.json({ data: result.items, nextCursor: result.nextCursor });
  }),

  getById: asyncHandler(async (req: Request, res: Response) => {
    const garage = await garageService.getById(req.params.garageId, req.user?.sub);
    res.json({ data: garage });
  }),

  myGarages: asyncHandler(async (req: Request, res: Response) => {
    const { cursor, limit } = req.query as unknown as { cursor?: string; limit: number };
    const result = await garageService.listByOwner(req.user!.sub, { cursor, limit });
    res.json({ data: result.items, nextCursor: result.nextCursor });
  }),

  update: asyncHandler(async (req: Request, res: Response) => {
    const garage = await garageService.update(req.params.garageId, req.user!.sub, req.body);
    res.json({ data: garage });
  }),

  remove: asyncHandler(async (req: Request, res: Response) => {
    await garageService.remove(req.params.garageId, req.user!.sub);
    res.status(204).send();
  }),

  follow: asyncHandler(async (req: Request, res: Response) => {
    await garageService.follow(req.params.garageId, req.user!.sub);
    res.status(204).send();
  }),

  unfollow: asyncHandler(async (req: Request, res: Response) => {
    await garageService.unfollow(req.params.garageId, req.user!.sub);
    res.status(204).send();
  }),
};
