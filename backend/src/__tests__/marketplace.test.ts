import { describe, it, expect, vi } from "vitest";
import request from "supertest";
import jwt from "jsonwebtoken";
import { randomUUID } from "node:crypto";

vi.mock("../config/prisma", () => {
  const listings = new Map<string, any>();
  const images = new Map<string, any>();
  const favorites = new Map<string, any>();
  const vehicles = new Map<string, any>();
  const nextId = () => randomUUID();

  const listingImageDelegate = {
    deleteMany: vi.fn(async ({ where }: any) => {
      for (const [id, img] of images) if (img.listingId === where.listingId) images.delete(id);
      return { count: 0 };
    }),
    createMany: vi.fn(async ({ data }: any) => {
      for (const d of data) images.set(nextId(), { id: nextId(), createdAt: new Date(), ...d });
      return { count: data.length };
    }),
  };

  const listingDelegate = {
    create: vi.fn(async ({ data }: any) => {
      const { images: imageCreate, ...rest } = data;
      const listing = { id: nextId(), status: "ACTIVE", viewCount: 0, createdAt: new Date(), updatedAt: new Date(), ...rest };
      listings.set(listing.id, listing);
      if (imageCreate?.create) {
        for (const img of imageCreate.create) images.set(nextId(), { id: nextId(), listingId: listing.id, ...img });
      }
      return { ...listing, images: [...images.values()].filter((i) => i.listingId === listing.id) };
    }),
    findUnique: vi.fn(async ({ where }: any) => listings.get(where.id) ?? null),
    findMany: vi.fn(async ({ where }: any) => {
      return [...listings.values()]
        .filter((l) => {
          if (where.status && l.status !== where.status) return false;
          if (where.sellerId && l.sellerId !== where.sellerId) return false;
          if (where.type && l.type !== where.type) return false;
          if (where.priceCents?.gte !== undefined && l.priceCents < where.priceCents.gte) return false;
          if (where.priceCents?.lte !== undefined && l.priceCents > where.priceCents.lte) return false;
          if (where.title?.contains && !l.title.toLowerCase().includes(where.title.contains.toLowerCase())) return false;
          return true;
        })
        .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
        .map((l) => ({ ...l, images: [...images.values()].filter((i) => i.listingId === l.id).slice(0, 1) }));
    }),
    update: vi.fn(async ({ where, data }: any) => {
      const listing = listings.get(where.id);
      if (data.viewCount?.increment) listing.viewCount += data.viewCount.increment;
      else Object.assign(listing, data);
      return listing;
    }),
  };

  return {
    prisma: {
      listing: listingDelegate,
      listingImage: listingImageDelegate,
      listingFavorite: {
        upsert: vi.fn(async ({ where, create }: any) => {
          const key = `${where.listingId_userId.listingId}:${where.listingId_userId.userId}`;
          const fav = favorites.get(key) ?? { id: nextId(), createdAt: new Date(), ...create };
          favorites.set(key, fav);
          return fav;
        }),
        deleteMany: vi.fn(async ({ where }: any) => {
          favorites.delete(`${where.listingId}:${where.userId}`);
          return { count: 1 };
        }),
        findMany: vi.fn(async ({ where }: any) =>
          [...favorites.values()]
            .filter((f) => f.userId === where.userId)
            .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
            .map((f) => ({
              ...f,
              listing: {
                ...listings.get(f.listingId),
                images: [...images.values()].filter((i) => i.listingId === f.listingId).slice(0, 1),
              },
            }))
        ),
      },
      vehicle: {
        findUnique: vi.fn(async ({ where }: any) => {
          const v = vehicles.get(where.id);
          if (!v) return null;
          return { ...v, garage: { ownerId: v.garageOwnerId } };
        }),
      },
      $transaction: vi.fn(async (fn: any) => fn({ listingImage: listingImageDelegate, listing: listingDelegate })),
      __seedVehicle: vehicles,
    },
  };
});

vi.mock("../config/redis", () => ({
  redis: { sendCommand: vi.fn(async () => "OK"), isOpen: true, connect: vi.fn(), quit: vi.fn(), on: vi.fn() },
  connectRedis: vi.fn(async () => {}),
}));

vi.mock("../middleware/rateLimit", () => ({
  authRateLimiter: (_req: unknown, _res: unknown, next: () => void) => next(),
  apiRateLimiter: (_req: unknown, _res: unknown, next: () => void) => next(),
}));

process.env.JWT_ACCESS_SECRET = "a".repeat(32);
process.env.DATABASE_URL = "postgresql://test";
process.env.REDIS_URL = "redis://test";

const { createApp } = await import("../app");
const { prisma } = (await import("../config/prisma")) as any;

function tokenFor(userId: string) {
  return jwt.sign({ sub: userId, role: "USER" }, process.env.JWT_ACCESS_SECRET!, { expiresIn: "15m" });
}

describe("Marketplace module", () => {
  const app = createApp();
  const seller = tokenFor("user_seller");
  const buyer = tokenFor("user_buyer");
  const stranger = tokenFor("user_stranger");
  let listingId: string;

  it("creates a listing", async () => {
    const res = await request(app)
      .post("/api/v1/marketplace")
      .set("Authorization", `Bearer ${seller}`)
      .send({
        type: "PART",
        title: "K24 head, ported and polished",
        description: "Fresh off the bench, great condition",
        priceCents: 85000,
        imageUrls: ["https://example.com/1.jpg", "https://example.com/2.jpg"],
      });
    expect(res.status).toBe(201);
    expect(res.body.data.images).toHaveLength(2);
    listingId = res.body.data.id;
  });

  it("blocks linking a vehicle you don't own", async () => {
    const otherVehicleId = randomUUID();
    prisma.__seedVehicle.set(otherVehicleId, { id: otherVehicleId, garageOwnerId: "user_someone_else" });

    const res = await request(app)
      .post("/api/v1/marketplace")
      .set("Authorization", `Bearer ${seller}`)
      .send({
        type: "CAR",
        title: "My friend's car (not mine)",
        description: "test",
        priceCents: 1000000,
        vehicleId: otherVehicleId,
        imageUrls: [],
      });
    expect(res.status).toBe(403);
  });

  it("allows linking a vehicle you do own", async () => {
    const ownVehicleId = randomUUID();
    prisma.__seedVehicle.set(ownVehicleId, { id: ownVehicleId, garageOwnerId: "user_seller" });

    const res = await request(app)
      .post("/api/v1/marketplace")
      .set("Authorization", `Bearer ${seller}`)
      .send({
        type: "CAR",
        title: "My actual car",
        description: "test",
        priceCents: 2000000,
        vehicleId: ownVehicleId,
        imageUrls: [],
      });
    expect(res.status).toBe(201);
  });

  it("lists active listings publicly with no auth", async () => {
    const res = await request(app).get("/api/v1/marketplace");
    expect(res.status).toBe(200);
    expect(res.body.data.some((l: any) => l.id === listingId)).toBe(true);
  });

  it("filters by price range", async () => {
    const res = await request(app).get("/api/v1/marketplace?minPriceCents=1000000");
    expect(res.status).toBe(200);
    expect(res.body.data.every((l: any) => l.priceCents >= 1000000)).toBe(true);
  });

  it("filters by search term", async () => {
    const res = await request(app).get("/api/v1/marketplace?search=K24");
    expect(res.status).toBe(200);
    expect(res.body.data.length).toBeGreaterThan(0);
    expect(res.body.data.every((l: any) => l.title.toLowerCase().includes("k24"))).toBe(true);
  });

  it("increments view count for a non-owner viewer", async () => {
    await request(app).get(`/api/v1/marketplace/${listingId}`).set("Authorization", `Bearer ${buyer}`);
    const res = await request(app).get(`/api/v1/marketplace/${listingId}`).set("Authorization", `Bearer ${buyer}`);
    expect(res.body.data.viewCount).toBe(2);
  });

  it("does not increment view count for the seller viewing their own listing", async () => {
    const before = await request(app)
      .get(`/api/v1/marketplace/${listingId}`)
      .set("Authorization", `Bearer ${seller}`);
    const countBefore = before.body.data.viewCount;

    const after = await request(app)
      .get(`/api/v1/marketplace/${listingId}`)
      .set("Authorization", `Bearer ${seller}`);
    expect(after.body.data.viewCount).toBe(countBefore);
  });

  it("prevents a non-owner from updating the listing", async () => {
    const res = await request(app)
      .patch(`/api/v1/marketplace/${listingId}`)
      .set("Authorization", `Bearer ${stranger}`)
      .send({ title: "Hijacked" });
    expect(res.status).toBe(403);
  });

  it("lets the owner update the listing and replace images", async () => {
    const res = await request(app)
      .patch(`/api/v1/marketplace/${listingId}`)
      .set("Authorization", `Bearer ${seller}`)
      .send({ priceCents: 75000, imageUrls: ["https://example.com/new.jpg"] });
    expect(res.status).toBe(200);
    expect(res.body.data.priceCents).toBe(75000);
  });

  it("hides a DRAFT listing from a stranger but shows it to the owner", async () => {
    const draftRes = await request(app)
      .post("/api/v1/marketplace")
      .set("Authorization", `Bearer ${seller}`)
      .send({ type: "TOOLS", title: "Draft listing", description: "wip", priceCents: 500, imageUrls: [] });
    const draftId = draftRes.body.data.id;
    await request(app)
      .patch(`/api/v1/marketplace/${draftId}/status`)
      .set("Authorization", `Bearer ${seller}`)
      .send({ status: "DRAFT" });

    const strangerView = await request(app)
      .get(`/api/v1/marketplace/${draftId}`)
      .set("Authorization", `Bearer ${stranger}`);
    expect(strangerView.status).toBe(404);

    const ownerView = await request(app)
      .get(`/api/v1/marketplace/${draftId}`)
      .set("Authorization", `Bearer ${seller}`);
    expect(ownerView.status).toBe(200);
  });

  it("lets a buyer favorite and unfavorite a listing", async () => {
    const favRes = await request(app)
      .post(`/api/v1/marketplace/${listingId}/favorite`)
      .set("Authorization", `Bearer ${buyer}`);
    expect(favRes.status).toBe(204);

    const listRes = await request(app)
      .get("/api/v1/marketplace/favorites")
      .set("Authorization", `Bearer ${buyer}`);
    expect(listRes.body.data.some((l: any) => l.id === listingId)).toBe(true);

    const unfavRes = await request(app)
      .delete(`/api/v1/marketplace/${listingId}/favorite`)
      .set("Authorization", `Bearer ${buyer}`);
    expect(unfavRes.status).toBe(204);

    const listAfter = await request(app)
      .get("/api/v1/marketplace/favorites")
      .set("Authorization", `Bearer ${buyer}`);
    expect(listAfter.body.data.some((l: any) => l.id === listingId)).toBe(false);
  });

  it("requires auth to list 'my listings'", async () => {
    const res = await request(app).get("/api/v1/marketplace/mine");
    expect(res.status).toBe(401);
  });

  it("lists only the seller's own listings regardless of status", async () => {
    const res = await request(app).get("/api/v1/marketplace/mine").set("Authorization", `Bearer ${seller}`);
    expect(res.status).toBe(200);
    expect(res.body.data.every((l: any) => l.sellerId === "user_seller")).toBe(true);
    expect(res.body.data.some((l: any) => l.status === "DRAFT")).toBe(true);
  });

  it("marks a listing as sold", async () => {
    const res = await request(app)
      .patch(`/api/v1/marketplace/${listingId}/status`)
      .set("Authorization", `Bearer ${seller}`)
      .send({ status: "SOLD" });
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe("SOLD");
  });
});
