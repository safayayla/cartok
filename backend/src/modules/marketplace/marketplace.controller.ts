import { Request, Response } from "express";
import { marketplaceService } from "./marketplace.service";
import { asyncHandler } from "../../middleware/errors";

type ListQuery = {
  type?: string;
  sellerId?: string;
  minPriceCents?: number;
  maxPriceCents?: number;
  search?: string;
  cursor?: string;
  limit: number;
};

export const marketplaceController = {
  create: asyncHandler(async (req: Request, res: Response) => {
    const listing = await marketplaceService.create(req.user!.sub, req.body);
    res.status(201).json({ data: listing });
  }),

  list: asyncHandler(async (req: Request, res: Response) => {
    const query = req.query as unknown as ListQuery;
    const result = await marketplaceService.list(query);
    res.json({ data: result.items, nextCursor: result.nextCursor });
  }),

  listMine: asyncHandler(async (req: Request, res: Response) => {
    const { cursor, limit } = req.query as unknown as { cursor?: string; limit: number };
    const result = await marketplaceService.listMine(req.user!.sub, { cursor, limit });
    res.json({ data: result.items, nextCursor: result.nextCursor });
  }),

  listFavorites: asyncHandler(async (req: Request, res: Response) => {
    const { cursor, limit } = req.query as unknown as { cursor?: string; limit: number };
    const result = await marketplaceService.listFavorites(req.user!.sub, { cursor, limit });
    res.json({ data: result.items, nextCursor: result.nextCursor });
  }),

  getById: asyncHandler(async (req: Request, res: Response) => {
    const listing = await marketplaceService.getById(req.params.listingId, req.user?.sub);
    res.json({ data: listing });
  }),

  update: asyncHandler(async (req: Request, res: Response) => {
    const listing = await marketplaceService.update(req.params.listingId, req.user!.sub, req.body);
    res.json({ data: listing });
  }),

  updateStatus: asyncHandler(async (req: Request, res: Response) => {
    const listing = await marketplaceService.updateStatus(req.params.listingId, req.user!.sub, req.body.status);
    res.json({ data: listing });
  }),

  favorite: asyncHandler(async (req: Request, res: Response) => {
    await marketplaceService.favorite(req.params.listingId, req.user!.sub);
    res.status(204).send();
  }),

  unfavorite: asyncHandler(async (req: Request, res: Response) => {
    await marketplaceService.unfavorite(req.params.listingId, req.user!.sub);
    res.status(204).send();
  }),
};
