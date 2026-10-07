import { prisma } from "../../config/prisma";
import { Errors } from "../../middleware/errors";
import { decodeVin } from "../../utils/vinDecoder";
import { garageService } from "../garage/garage.service";
import { notificationsService } from "../notifications/notifications.service";
import type { CreateVehicleInput, UpdateVehicleInput } from "./vehicles.schemas";

export const vehiclesService = {
  /**
   * Delegates to garageService.assertOwnership rather than re-querying
   * ownership here — this exact check (load garage, compare ownerId) used
   * to be duplicated verbatim in both services; one implementation now,
   * shared by both.
   */
  async assertGarageOwnership(garageId: string, userId: string) {
    return garageService.assertOwnership(garageId, userId);
  },

  /**
   * Delegates to garageService.assertVisible - same reasoning as
   * assertGarageOwnership above: one implementation of "can this viewer
   * see this garage," not a second copy of the same query.
   */
  async assertGarageVisible(garageId: string, viewerId?: string) {
    return garageService.assertVisible(garageId, viewerId);
  },

  async create(garageId: string, userId: string, input: CreateVehicleInput) {
    await this.assertGarageOwnership(garageId, userId);

    let vinDecodedData: Record<string, string> | undefined;
    if (input.vin) {
      // Best-effort enrichment: if the decode service fails, the vehicle is
      // still created with the user-supplied data rather than blocking them.
      try {
        const decoded = await decodeVin(input.vin);
        vinDecodedData = decoded.raw;
      } catch {
        vinDecodedData = undefined;
      }
    }

    return prisma.vehicle.create({
      data: { ...input, garageId, vinDecodedData },
    });
  },

  async listByGarage(garageId: string, viewerId?: string, { cursor, limit = 20 }: { cursor?: string; limit?: number } = {}) {
    const garage = await this.assertGarageVisible(garageId, viewerId);
    const isOwner = garage.ownerId === viewerId;

    const vehicles = await prisma.vehicle.findMany({
      where: { garageId, ...(isOwner ? {} : { isPublic: true }) },
      orderBy: { createdAt: "desc" },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });

    const hasMore = vehicles.length > limit;
    const page = hasMore ? vehicles.slice(0, limit) : vehicles;
    return { items: page, nextCursor: hasMore ? page[page.length - 1].id : null };
  },

  async getById(garageId: string, vehicleId: string, viewerId?: string) {
    const garage = await this.assertGarageVisible(garageId, viewerId);
    const isOwner = garage.ownerId === viewerId;

    const vehicle = await prisma.vehicle.findFirst({
      where: { id: vehicleId, garageId },
      include: { _count: { select: { likes: true, comments: true } } },
    });
    if (!vehicle || (!vehicle.isPublic && !isOwner)) throw Errors.notFound("Vehicle not found");

    const isLikedByMe = viewerId
      ? Boolean(await prisma.vehicleLike.findUnique({ where: { vehicleId_userId: { vehicleId, userId: viewerId } } }))
      : false;

    const isBookmarkedByMe = viewerId
      ? Boolean(
          await prisma.vehicleBookmark.findUnique({ where: { vehicleId_userId: { vehicleId, userId: viewerId } } })
        )
      : false;

    return { ...vehicle, isLikedByMe, isBookmarkedByMe };
  },

  async update(garageId: string, vehicleId: string, userId: string, input: UpdateVehicleInput) {
    await this.assertGarageOwnership(garageId, userId);
    // Ownership already established above, so viewerId=userId here always
    // satisfies isOwner — this call exists to confirm the vehicle exists
    // in this garage before attempting the update.
    await this.getById(garageId, vehicleId, userId);
    return prisma.vehicle.update({ where: { id: vehicleId }, data: input });
  },

  async remove(garageId: string, vehicleId: string, userId: string) {
    await this.assertGarageOwnership(garageId, userId);
    await this.getById(garageId, vehicleId, userId);
    await prisma.vehicle.delete({ where: { id: vehicleId } });
  },

  async decodeVinPreview(vin: string) {
    return decodeVin(vin);
  },

  // --- Likes ---

  async like(garageId: string, vehicleId: string, userId: string) {
    const vehicle = await this.getById(garageId, vehicleId, userId);

    await prisma.vehicleLike.upsert({
      where: { vehicleId_userId: { vehicleId, userId } },
      create: { vehicleId, userId },
      update: {},
    });

    // Look up the owning garage separately for the notification recipient
    // — getById() already enforced visibility above, this is just for who
    // to notify, not another authorization check.
    const garage = await prisma.garage.findUnique({ where: { id: garageId }, select: { ownerId: true } });
    if (garage) {
      await notificationsService.emit({
        recipientId: garage.ownerId,
        actorId: userId,
        type: "VEHICLE_LIKE",
        message: `liked your ${vehicle.year} ${vehicle.make} ${vehicle.model}`,
        entityType: "Vehicle",
        entityId: vehicleId,
      });
    }
  },

  async unlike(garageId: string, vehicleId: string, userId: string) {
    await this.getById(garageId, vehicleId, userId);
    await prisma.vehicleLike.deleteMany({ where: { vehicleId, userId } });
  },

  // --- Comments ---

  async listComments(
    garageId: string,
    vehicleId: string,
    viewerId: string | undefined,
    { cursor, limit = 20 }: { cursor?: string; limit?: number }
  ) {
    await this.getById(garageId, vehicleId, viewerId);

    const comments = await prisma.vehicleComment.findMany({
      where: { vehicleId },
      orderBy: { createdAt: "asc" },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: { author: { select: { id: true, username: true, displayName: true, avatarUrl: true } } },
    });

    const hasMore = comments.length > limit;
    const page = hasMore ? comments.slice(0, limit) : comments;
    return {
      items: page.map((c: { isDeleted: boolean; content: string }) => ({
        ...c,
        content: c.isDeleted ? "[deleted]" : c.content,
      })),
      nextCursor: hasMore ? page[page.length - 1].id : null,
    };
  },

  async createComment(garageId: string, vehicleId: string, authorId: string, content: string) {
    const vehicle = await this.getById(garageId, vehicleId, authorId);

    const comment = await prisma.vehicleComment.create({
      data: { vehicleId, authorId, content },
    });

    const garage = await prisma.garage.findUnique({ where: { id: garageId }, select: { ownerId: true } });
    if (garage) {
      await notificationsService.emit({
        recipientId: garage.ownerId,
        actorId: authorId,
        type: "VEHICLE_COMMENT",
        message: `commented on your ${vehicle.year} ${vehicle.make} ${vehicle.model}`,
        entityType: "Vehicle",
        entityId: vehicleId,
      });
    }

    return comment;
  },

  async assertCommentAuthor(commentId: string, userId: string) {
    const comment = await prisma.vehicleComment.findUnique({ where: { id: commentId }, select: { authorId: true } });
    if (!comment) throw Errors.notFound("Comment not found");
    if (comment.authorId !== userId) throw Errors.forbidden("You can only edit your own comments");
    return comment;
  },

  async updateComment(commentId: string, userId: string, content: string) {
    await this.assertCommentAuthor(commentId, userId);
    return prisma.vehicleComment.update({ where: { id: commentId }, data: { content, editedAt: new Date() } });
  },

  async deleteComment(commentId: string, userId: string, isModerator: boolean) {
    const comment = await prisma.vehicleComment.findUnique({ where: { id: commentId }, select: { authorId: true } });
    if (!comment) throw Errors.notFound("Comment not found");
    if (comment.authorId !== userId && !isModerator) throw Errors.forbidden();

    // Soft delete, same reasoning as forum posts: preserve content for
    // moderation/audit, mask only at the read layer (listComments above).
    await prisma.vehicleComment.update({ where: { id: commentId }, data: { isDeleted: true } });
  },

  // --- Bookmarks ---

  async bookmark(garageId: string, vehicleId: string, userId: string) {
    await this.getById(garageId, vehicleId, userId);

    await prisma.vehicleBookmark.upsert({
      where: { vehicleId_userId: { vehicleId, userId } },
      create: { vehicleId, userId },
      update: {},
    });
  },

  async unbookmark(garageId: string, vehicleId: string, userId: string) {
    await this.getById(garageId, vehicleId, userId);
    await prisma.vehicleBookmark.deleteMany({ where: { vehicleId, userId } });
  },

  /**
   * Cross-garage: "vehicles I bookmarked," not scoped to one garage. A
   * bookmark can only be created on a vehicle the user could see at the
   * time, but visibility can change afterward — the owner can flip the
   * vehicle or its garage to private later. When that happens, this
   * quietly excludes it from the list (rather than 404ing the whole
   * request) unless the caller is the owner, who should still see their
   * own vehicles here regardless of the public/private flag.
   */
  async listBookmarkedVehicles(userId: string, { cursor, limit }: { cursor?: string; limit: number }) {
    const bookmarks = await prisma.vehicleBookmark.findMany({
      where: { userId },
      orderBy: { createdAt: "desc" },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: { vehicle: { include: { garage: true } } },
    });

    const hasMore = bookmarks.length > limit;
    const page = hasMore ? bookmarks.slice(0, limit) : bookmarks;

    const visible = page
      .map((b: { vehicle: { garage: { ownerId: string; isPublic: boolean }; isPublic: boolean } }) => b.vehicle)
      .filter((v: { garage: { ownerId: string; isPublic: boolean }; isPublic: boolean }) => {
        const isOwner = v.garage.ownerId === userId;
        if (isOwner) return true;
        return v.garage.isPublic && v.isPublic;
      });

    return {
      items: visible,
      nextCursor: hasMore ? page[page.length - 1].id : null,
    };
  },

  /**
   * Public vehicle search across all garages, by make/model/nickname.
   * Mirrors garageService.browse()'s exact pattern (isPublic filter
   * unconditional, case-insensitive `contains`, cursor pagination).
   *
   * Visibility is deliberately two levels, not one — same reasoning as
   * listBookmarks() just above: a vehicle can be `isPublic: true` while
   * sitting inside a non-public garage, and the garage's privacy must
   * still win. `garage: { isPublic: true }` is a relation filter enforced
   * by the query itself, not an application-level check a caller could
   * forget — the exact class of bug (a resource's own flag checked while
   * its parent's flag was overlooked) found and fixed early in this
   * project for garage/vehicle visibility generally.
   */
  async searchPublic({ search, cursor, limit }: { search?: string; cursor?: string; limit: number }) {
    const vehicles = await prisma.vehicle.findMany({
      where: {
        isPublic: true,
        garage: { isPublic: true },
        ...(search
          ? {
              OR: [
                { make: { contains: search, mode: "insensitive" } },
                { model: { contains: search, mode: "insensitive" } },
                { nickname: { contains: search, mode: "insensitive" } },
              ],
            }
          : {}),
      },
      orderBy: { createdAt: "desc" },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });

    const hasMore = vehicles.length > limit;
    const page = hasMore ? vehicles.slice(0, limit) : vehicles;
    return { items: page, nextCursor: hasMore ? page[page.length - 1].id : null };
  },
};
