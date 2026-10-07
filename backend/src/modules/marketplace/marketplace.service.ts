import { prisma } from "../../config/prisma";
import { Errors } from "../../middleware/errors";
import type { CreateListingInput, UpdateListingInput } from "./marketplace.schemas";

export const marketplaceService = {
  async assertOwnership(listingId: string, userId: string) {
    const listing = await prisma.listing.findUnique({ where: { id: listingId }, select: { sellerId: true } });
    if (!listing) throw Errors.notFound("Listing not found");
    if (listing.sellerId !== userId) throw Errors.forbidden("You do not own this listing");
    return listing;
  },

  async create(sellerId: string, input: CreateListingInput) {
    // A listing can reference one of the seller's own vehicles (e.g. "selling
    // this car from my garage") — never someone else's, which would let a
    // user borrow another person's vehicle photos/verification for their own
    // listing.
    if (input.vehicleId) {
      const vehicle = await prisma.vehicle.findUnique({
        where: { id: input.vehicleId },
        include: { garage: { select: { ownerId: true } } },
      });
      if (!vehicle || vehicle.garage.ownerId !== sellerId) {
        throw Errors.forbidden("You can only link a vehicle from your own garage");
      }
    }

    const { imageUrls, ...listingData } = input;

    return prisma.listing.create({
      data: {
        ...listingData,
        sellerId,
        images: { create: imageUrls.map((url, index) => ({ url, sortOrder: index })) },
      },
      include: { images: true },
    });
  },

  async list({
    type,
    sellerId,
    minPriceCents,
    maxPriceCents,
    search,
    cursor,
    limit,
  }: {
    type?: string;
    sellerId?: string;
    minPriceCents?: number;
    maxPriceCents?: number;
    search?: string;
    cursor?: string;
    limit: number;
  }) {
    const listings = await prisma.listing.findMany({
      where: {
        // Public browsing only ever shows ACTIVE listings, regardless of
        // who's asking — a seller's other statuses (DRAFT/SOLD/REMOVED) are
        // only visible via the dedicated "my listings" endpoint.
        status: "ACTIVE",
        ...(type ? { type: type as never } : {}),
        ...(sellerId ? { sellerId } : {}),
        ...(minPriceCents !== undefined || maxPriceCents !== undefined
          ? { priceCents: { gte: minPriceCents, lte: maxPriceCents } }
          : {}),
        ...(search ? { title: { contains: search, mode: "insensitive" } } : {}),
      },
      orderBy: { createdAt: "desc" },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: { images: { orderBy: { sortOrder: "asc" }, take: 1 } },
    });

    const hasMore = listings.length > limit;
    const page = hasMore ? listings.slice(0, limit) : listings;
    return { items: page, nextCursor: hasMore ? page[page.length - 1].id : null };
  },

  async listMine(sellerId: string, { cursor, limit }: { cursor?: string; limit: number }) {
    const listings = await prisma.listing.findMany({
      where: { sellerId },
      orderBy: { createdAt: "desc" },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: { images: { orderBy: { sortOrder: "asc" }, take: 1 } },
    });

    const hasMore = listings.length > limit;
    const page = hasMore ? listings.slice(0, limit) : listings;
    return { items: page, nextCursor: hasMore ? page[page.length - 1].id : null };
  },

  async getById(listingId: string, viewerId?: string) {
    const listing = await prisma.listing.findUnique({
      where: { id: listingId },
      include: {
        images: { orderBy: { sortOrder: "asc" } },
        seller: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
        _count: { select: { favorites: true } },
      },
    });

    // Draft/removed listings are only visible to their seller — a listing
    // being ACTIVE or SOLD is fine to show publicly (a sold listing is
    // useful social proof / price history), but DRAFT and REMOVED are not.
    if (!listing || ((listing.status === "DRAFT" || listing.status === "REMOVED") && listing.sellerId !== viewerId)) {
      throw Errors.notFound("Listing not found");
    }

    // Best-effort view count; not critical if this races under concurrent views.
    if (viewerId !== listing.sellerId) {
      await prisma.listing.update({ where: { id: listingId }, data: { viewCount: { increment: 1 } } });
    }

    return listing;
  },

  async update(listingId: string, sellerId: string, input: UpdateListingInput) {
    await this.assertOwnership(listingId, sellerId);
    const { imageUrls, ...listingData } = input;

    return prisma.$transaction(async (tx: typeof prisma) => {
      if (imageUrls) {
        await tx.listingImage.deleteMany({ where: { listingId } });
        await tx.listingImage.createMany({
          data: imageUrls.map((url, index) => ({ listingId, url, sortOrder: index })),
        });
      }
      return tx.listing.update({
        where: { id: listingId },
        data: listingData,
        include: { images: { orderBy: { sortOrder: "asc" } } },
      });
    });
  },

  async updateStatus(listingId: string, sellerId: string, status: "ACTIVE" | "SOLD" | "DRAFT" | "REMOVED") {
    await this.assertOwnership(listingId, sellerId);
    return prisma.listing.update({ where: { id: listingId }, data: { status } });
  },

  async favorite(listingId: string, userId: string) {
    const listing = await prisma.listing.findUnique({ where: { id: listingId }, select: { id: true } });
    if (!listing) throw Errors.notFound("Listing not found");

    return prisma.listingFavorite.upsert({
      where: { listingId_userId: { listingId, userId } },
      create: { listingId, userId },
      update: {},
    });
  },

  async unfavorite(listingId: string, userId: string) {
    await prisma.listingFavorite.deleteMany({ where: { listingId, userId } });
  },

  async listFavorites(userId: string, { cursor, limit }: { cursor?: string; limit: number }) {
    const favorites = await prisma.listingFavorite.findMany({
      where: { userId },
      orderBy: { createdAt: "desc" },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: { listing: { include: { images: { orderBy: { sortOrder: "asc" }, take: 1 } } } },
    });

    const hasMore = favorites.length > limit;
    const page = hasMore ? favorites.slice(0, limit) : favorites;
    return {
      items: page.map((f: { listing: unknown }) => f.listing),
      nextCursor: hasMore ? page[page.length - 1].id : null,
    };
  },
};
