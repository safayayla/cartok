import { prisma } from "../../config/prisma";
import { Errors } from "../../middleware/errors";
import { notificationsService } from "../notifications/notifications.service";
import { slugify, CreateGarageInput, UpdateGarageInput } from "./garage.schemas";

async function uniqueSlug(base: string): Promise<string> {
  const slug = slugify(base) || "garage";
  let suffix = 0;
  // Small bounded loop — garage name collisions are rare, and this guarantees
  // termination rather than looping forever if something is very wrong.
  while (suffix < 50) {
    const candidate = suffix === 0 ? slug : `${slug}-${suffix}`;
    const existing = await prisma.garage.findUnique({ where: { slug: candidate }, select: { id: true } });
    if (!existing) return candidate;
    suffix += 1;
  }
  throw Errors.internal("Could not generate a unique garage slug");
}

export const garageService = {
  async create(ownerId: string, input: CreateGarageInput) {
    const slug = await uniqueSlug(input.name);
    return prisma.garage.create({
      data: { ...input, slug, ownerId },
    });
  },

  /**
   * Public browse/search — deliberately always filters to isPublic: true
   * regardless of viewer, unlike getById/assertVisible which allow an
   * owner to see their own private garage by direct ID. There's no
   * equivalent "show me my own private garage in browse results" need
   * here since /garages/mine already covers that; keeping this endpoint
   * unconditionally public-only avoids ever needing per-row visibility
   * logic in a list endpoint (a common source of accidental leaks).
   */
  async browse({ search, cursor, limit }: { search?: string; cursor?: string; limit: number }) {
    const garages = await prisma.garage.findMany({
      where: {
        isPublic: true,
        ...(search ? { name: { contains: search, mode: "insensitive" } } : {}),
      },
      orderBy: { createdAt: "desc" },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: { _count: { select: { followers: true, vehicles: true } } },
    });

    const hasMore = garages.length > limit;
    const page = hasMore ? garages.slice(0, limit) : garages;
    return { items: page, nextCursor: hasMore ? page[page.length - 1].id : null };
  },

  /**
   * Single source of truth for "can this viewer see this garage at all."
   * Returns 404 (not 403) when hidden — a 403 would confirm the garage
   * exists, leaking its presence to anyone probing garage IDs; 404 is
   * indistinguishable from "doesn't exist."
   */
  async assertVisible(garageId: string, viewerId?: string) {
    const garage = await prisma.garage.findUnique({ where: { id: garageId } });
    if (!garage || (!garage.isPublic && garage.ownerId !== viewerId)) {
      throw Errors.notFound("Garage not found");
    }
    return garage;
  },

  async getById(garageId: string, viewerId?: string) {
    const garage = await prisma.garage.findUnique({
      where: { id: garageId },
      include: {
        vehicles: true,
        _count: { select: { followers: true } },
      },
    });
    if (!garage || (!garage.isPublic && garage.ownerId !== viewerId)) {
      throw Errors.notFound("Garage not found");
    }

    // The garage being public doesn't make every vehicle in it public —
    // Vehicle has its own isPublic flag that must be respected independently.
    const isOwner = garage.ownerId === viewerId;

    const isFollowedByMe =
      viewerId && !isOwner
        ? Boolean(
            await prisma.garageFollower.findUnique({
              where: { garageId_userId: { garageId, userId: viewerId } },
            })
          )
        : false;

    return {
      ...garage,
      vehicles: isOwner ? garage.vehicles : garage.vehicles.filter((v: { isPublic: boolean }) => v.isPublic),
      isFollowedByMe,
    };
  },

  async listByOwner(ownerId: string, { cursor, limit = 20 }: { cursor?: string; limit?: number } = {}) {
    const garages = await prisma.garage.findMany({
      where: { ownerId },
      orderBy: { createdAt: "desc" },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });

    const hasMore = garages.length > limit;
    const page = hasMore ? garages.slice(0, limit) : garages;
    return { items: page, nextCursor: hasMore ? page[page.length - 1].id : null };
  },

  async assertOwnership(garageId: string, userId: string) {
    const garage = await prisma.garage.findUnique({ where: { id: garageId }, select: { ownerId: true } });
    if (!garage) throw Errors.notFound("Garage not found");
    if (garage.ownerId !== userId) throw Errors.forbidden("You do not own this garage");
    return garage;
  },

  async update(garageId: string, userId: string, input: UpdateGarageInput) {
    await this.assertOwnership(garageId, userId);
    return prisma.garage.update({ where: { id: garageId }, data: input });
  },

  async remove(garageId: string, userId: string) {
    await this.assertOwnership(garageId, userId);
    await prisma.garage.delete({ where: { id: garageId } });
  },

  async follow(garageId: string, userId: string) {
    const garage = await prisma.garage.findUnique({ where: { id: garageId } });
    if (!garage) throw Errors.notFound("Garage not found");

    const result = await prisma.garageFollower.upsert({
      where: { garageId_userId: { garageId, userId } },
      create: { garageId, userId },
      update: {},
    });

    await notificationsService.emit({
      recipientId: garage.ownerId,
      actorId: userId,
      type: "GARAGE_FOLLOW",
      message: "started following your garage",
      entityType: "Garage",
      entityId: garageId,
    });

    return result;
  },

  async unfollow(garageId: string, userId: string) {
    await prisma.garageFollower.deleteMany({ where: { garageId, userId } });
  },
};
