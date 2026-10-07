import { Request, Response } from "express";
import { discoverService } from "./discover.service";
import { asyncHandler } from "../../middleware/errors";

export const discoverController = {
  getFeed: asyncHandler(async (req: Request, res: Response) => {
    const { limit } = req.query as unknown as { limit: number };
    const items = await discoverService.getFeed(req.user?.sub, limit);
    res.json({ data: items });
  }),
};
