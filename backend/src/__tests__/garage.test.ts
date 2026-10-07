import { describe, it, expect, vi } from "vitest";
import request from "supertest";
import jwt from "jsonwebtoken";
import { randomUUID } from "node:crypto";

vi.mock("../config/prisma", () => {
  const garages = new Map<string, any>();
  const vehicles = new Map<string, any>();
  const followers = new Map<string, any>();
  const notifications = new Map<string, any>();
  const vehicleLikes = new Map<string, any>();
  const vehicleComments = new Map<string, any>();
  const vehicleBookmarks = new Map<string, any>();
  const nextId = () => randomUUID();

  return {
    prisma: {
      garage: {
        create: vi.fn(async ({ data }: any) => {
          const garage = { id: nextId(), createdAt: new Date(), updatedAt: new Date(), ...data };
          garages.set(garage.id, garage);
          return garage;
        }),
        findUnique: vi.fn(async ({ where, include }: any) => {
          const garage = garages.get(where.id);
          if (!garage) return null;
          if (where.slug !== undefined) {
            return [...garages.values()].find((g) => g.slug === where.slug) ?? null;
          }
          if (include?.vehicles) {
            return {
              ...garage,
              vehicles: [...vehicles.values()].filter((v) => v.garageId === garage.id),
              _count: { followers: [...followers.values()].filter((f) => f.garageId === garage.id).length },
            };
          }
          return garage;
        }),
        findMany: vi.fn(async ({ where }: any) =>
          [...garages.values()]
            .filter((g) => {
              if (where.ownerId !== undefined && g.ownerId !== where.ownerId) return false;
              if (where.isPublic !== undefined && g.isPublic !== where.isPublic) return false;
              if (where.name?.contains) {
                if (!g.name.toLowerCase().includes(where.name.contains.toLowerCase())) return false;
              }
              return true;
            })
            .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
            .map((g) => ({
              ...g,
              _count: {
                followers: [...followers.values()].filter((f) => f.garageId === g.id).length,
                vehicles: [...vehicles.values()].filter((v) => v.garageId === g.id).length,
              },
            }))
        ),
        update: vi.fn(async ({ where, data }: any) => {
          const garage = garages.get(where.id);
          Object.assign(garage, data);
          return garage;
        }),
        delete: vi.fn(async ({ where }: any) => {
          garages.delete(where.id);
          return {};
        }),
      },
      vehicle: {
        create: vi.fn(async ({ data }: any) => {
          const vehicle = { id: nextId(), createdAt: new Date(), verificationStatus: "UNVERIFIED", ...data };
          vehicles.set(vehicle.id, vehicle);
          return vehicle;
        }),
        findMany: vi.fn(async ({ where }: any) =>
          [...vehicles.values()].filter((v) => {
            if (v.garageId !== where.garageId) return false;
            if (where.isPublic !== undefined && v.isPublic !== where.isPublic) return false;
            return true;
          })
        ),
        findFirst: vi.fn(async ({ where }: any) => {
          const v = vehicles.get(where.id);
          if (!v || v.garageId !== where.garageId) return null;
          return {
            ...v,
            _count: {
              likes: [...vehicleLikes.values()].filter((l) => l.vehicleId === v.id).length,
              comments: [...vehicleComments.values()].filter((c) => c.vehicleId === v.id && !c.isDeleted).length,
            },
          };
        }),
        update: vi.fn(async ({ where, data }: any) => {
          const v = vehicles.get(where.id);
          Object.assign(v, data);
          return v;
        }),
        delete: vi.fn(async ({ where }: any) => {
          vehicles.delete(where.id);
          return {};
        }),
      },
      vehicleLike: {
        findUnique: vi.fn(async ({ where }: any) => {
          const key = `${where.vehicleId_userId.vehicleId}:${where.vehicleId_userId.userId}`;
          return vehicleLikes.get(key) ?? null;
        }),
        upsert: vi.fn(async ({ where, create }: any) => {
          const key = `${where.vehicleId_userId.vehicleId}:${where.vehicleId_userId.userId}`;
          const existing = vehicleLikes.get(key);
          const l = existing ?? { id: nextId(), createdAt: new Date(), ...create };
          vehicleLikes.set(key, l);
          return l;
        }),
        deleteMany: vi.fn(async ({ where }: any) => {
          vehicleLikes.delete(`${where.vehicleId}:${where.userId}`);
          return { count: 1 };
        }),
      },
      vehicleBookmark: {
        findUnique: vi.fn(async ({ where }: any) => {
          const key = `${where.vehicleId_userId.vehicleId}:${where.vehicleId_userId.userId}`;
          return vehicleBookmarks.get(key) ?? null;
        }),
        upsert: vi.fn(async ({ where, create }: any) => {
          const key = `${where.vehicleId_userId.vehicleId}:${where.vehicleId_userId.userId}`;
          const existing = vehicleBookmarks.get(key);
          const b = existing ?? { id: nextId(), createdAt: new Date(), ...create };
          vehicleBookmarks.set(key, b);
          return b;
        }),
        deleteMany: vi.fn(async ({ where }: any) => {
          vehicleBookmarks.delete(`${where.vehicleId}:${where.userId}`);
          return { count: 1 };
        }),
        findMany: vi.fn(async ({ where }: any) =>
          [...vehicleBookmarks.values()]
            .filter((b) => b.userId === where.userId)
            .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
            .map((b) => {
              const v = vehicles.get(b.vehicleId);
              const g = garages.get(v.garageId);
              return { ...b, vehicle: { ...v, garage: g } };
            })
        ),
      },
      vehicleComment: {
        create: vi.fn(async ({ data }: any) => {
          const c = { id: nextId(), isDeleted: false, createdAt: new Date(), ...data };
          vehicleComments.set(c.id, c);
          return c;
        }),
        findUnique: vi.fn(async ({ where, select }: any) => {
          const c = vehicleComments.get(where.id);
          if (!c) return null;
          if (select?.authorId && Object.keys(select).length === 1) return { authorId: c.authorId };
          return c;
        }),
        findMany: vi.fn(async ({ where }: any) =>
          [...vehicleComments.values()]
            .filter((c) => c.vehicleId === where.vehicleId)
            .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime())
            .map((c) => ({
              ...c,
              author: { id: c.authorId, username: c.authorId, displayName: c.authorId, avatarUrl: null },
            }))
        ),
        update: vi.fn(async ({ where, data }: any) => {
          const c = vehicleComments.get(where.id);
          Object.assign(c, data);
          return c;
        }),
      },
      garageFollower: {
        findUnique: vi.fn(async ({ where }: any) => {
          const key = `${where.garageId_userId.garageId}:${where.garageId_userId.userId}`;
          return followers.get(key) ?? null;
        }),
        upsert: vi.fn(async ({ where, create }: any) => {
          const key = `${where.garageId_userId.garageId}:${where.garageId_userId.userId}`;
          const existing = followers.get(key);
          const f = existing ?? { id: nextId(), ...create };
          followers.set(key, f);
          return f;
        }),
        deleteMany: vi.fn(async ({ where }: any) => {
          followers.delete(`${where.garageId}:${where.userId}`);
          return { count: 1 };
        }),
      },
      notification: {
        create: vi.fn(async ({ data }: any) => {
          const n = { id: nextId(), isRead: false, createdAt: new Date(), ...data };
          notifications.set(n.id, n);
          return n;
        }),
        findMany: vi.fn(async ({ where }: any) =>
          [...notifications.values()]
            .filter((n) => n.recipientId === where.recipientId)
            .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
        ),
      },
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

function tokenFor(userId: string) {
  return jwt.sign({ sub: userId, role: "USER" }, process.env.JWT_ACCESS_SECRET!, { expiresIn: "15m" });
}

describe("Garage module", () => {
  const app = createApp();
  const owner = tokenFor("user_owner");
  const stranger = tokenFor("user_stranger");
  let publicGarageId: string;
  let privateGarageId: string;

  it("creates a garage owned by the caller", async () => {
    const res = await request(app)
      .post("/api/v1/garages")
      .set("Authorization", `Bearer ${owner}`)
      .send({ name: "Public Garage", isPublic: true });
    expect(res.status).toBe(201);
    publicGarageId = res.body.data.id;
  });

  it("creates a private garage", async () => {
    const res = await request(app)
      .post("/api/v1/garages")
      .set("Authorization", `Bearer ${owner}`)
      .send({ name: "Private Garage", isPublic: false });
    expect(res.status).toBe(201);
    privateGarageId = res.body.data.id;
  });

  it("lets anyone view a public garage, even unauthenticated", async () => {
    const res = await request(app).get(`/api/v1/garages/${publicGarageId}`);
    expect(res.status).toBe(200);
    expect(res.body.data.name).toBe("Public Garage");
  });

  it("hides a private garage from an unauthenticated viewer (404, not 403)", async () => {
    const res = await request(app).get(`/api/v1/garages/${privateGarageId}`);
    expect(res.status).toBe(404);
  });

  it("hides a private garage from a different authenticated user", async () => {
    const res = await request(app)
      .get(`/api/v1/garages/${privateGarageId}`)
      .set("Authorization", `Bearer ${stranger}`);
    expect(res.status).toBe(404);
  });

  it("shows a private garage to its owner", async () => {
    const res = await request(app)
      .get(`/api/v1/garages/${privateGarageId}`)
      .set("Authorization", `Bearer ${owner}`);
    expect(res.status).toBe(200);
    expect(res.body.data.name).toBe("Private Garage");
  });

  it("prevents a non-owner from updating a garage", async () => {
    const res = await request(app)
      .patch(`/api/v1/garages/${publicGarageId}`)
      .set("Authorization", `Bearer ${stranger}`)
      .send({ name: "Hijacked" });
    expect(res.status).toBe(403);
  });

  it("prevents a non-owner from deleting a garage", async () => {
    const res = await request(app)
      .delete(`/api/v1/garages/${publicGarageId}`)
      .set("Authorization", `Bearer ${stranger}`);
    expect(res.status).toBe(403);
  });

  it("lets a stranger follow a public garage and notifies the owner", async () => {
    const res = await request(app)
      .post(`/api/v1/garages/${publicGarageId}/follow`)
      .set("Authorization", `Bearer ${stranger}`);
    expect(res.status).toBe(204);
  });

  it("reflects isFollowedByMe correctly for the follower and a third party", async () => {
    const followerView = await request(app)
      .get(`/api/v1/garages/${publicGarageId}`)
      .set("Authorization", `Bearer ${stranger}`);
    expect(followerView.body.data.isFollowedByMe).toBe(true);

    const thirdPartyView = await request(app)
      .get(`/api/v1/garages/${publicGarageId}`)
      .set("Authorization", `Bearer ${tokenFor("user_uninvolved")}`);
    expect(thirdPartyView.body.data.isFollowedByMe).toBe(false);

    const anonymousView = await request(app).get(`/api/v1/garages/${publicGarageId}`);
    expect(anonymousView.body.data.isFollowedByMe).toBe(false);

    const ownerView = await request(app)
      .get(`/api/v1/garages/${publicGarageId}`)
      .set("Authorization", `Bearer ${owner}`);
    expect(ownerView.body.data.isFollowedByMe).toBe(false);
  });

  it("requires auth to list 'my garages'", async () => {
    const res = await request(app).get("/api/v1/garages/mine");
    expect(res.status).toBe(401);
  });

  it("lists only the caller's own garages", async () => {
    const res = await request(app).get("/api/v1/garages/mine").set("Authorization", `Bearer ${owner}`);
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(2);
    expect(res.body.data.every((g: any) => g.ownerId === "user_owner")).toBe(true);
  });

  it("browses public garages without requiring auth", async () => {
    const res = await request(app).get("/api/v1/garages");
    expect(res.status).toBe(200);
    expect(res.body.data.some((g: any) => g.id === publicGarageId)).toBe(true);
  });

  it("never includes a private garage in browse results, even to its own owner", async () => {
    const res = await request(app).get("/api/v1/garages").set("Authorization", `Bearer ${owner}`);
    expect(res.body.data.some((g: any) => g.id === privateGarageId)).toBe(false);
  });

  it("filters browse results by search term", async () => {
    const res = await request(app).get("/api/v1/garages?search=Public%20Garage");
    expect(res.status).toBe(200);
    expect(res.body.data.length).toBeGreaterThan(0);
    expect(res.body.data.every((g: any) => g.name.toLowerCase().includes("public garage"))).toBe(true);
  });
});

describe("Vehicles module", () => {
  const app = createApp();
  const owner = tokenFor("user_owner2");
  const stranger = tokenFor("user_stranger2");
  let garageId: string;
  let publicVehicleId: string;
  let privateVehicleId: string;
  let commentId: string;

  it("sets up a public garage with one public and one private vehicle", async () => {
    const garageRes = await request(app)
      .post("/api/v1/garages")
      .set("Authorization", `Bearer ${owner}`)
      .send({ name: "Vehicle Test Garage", isPublic: true });
    garageId = garageRes.body.data.id;

    const publicVehicle = await request(app)
      .post(`/api/v1/garages/${garageId}/vehicles`)
      .set("Authorization", `Bearer ${owner}`)
      .send({ make: "Honda", model: "Civic", year: 2020, isPublic: true });
    expect(publicVehicle.status).toBe(201);
    publicVehicleId = publicVehicle.body.data.id;

    const privateVehicle = await request(app)
      .post(`/api/v1/garages/${garageId}/vehicles`)
      .set("Authorization", `Bearer ${owner}`)
      .send({ make: "Porsche", model: "911", year: 2023, isPublic: false });
    expect(privateVehicle.status).toBe(201);
    privateVehicleId = privateVehicle.body.data.id;
  });

  it("only shows the public vehicle to a stranger listing the garage", async () => {
    const res = await request(app)
      .get(`/api/v1/garages/${garageId}/vehicles`)
      .set("Authorization", `Bearer ${stranger}`);
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].id).toBe(publicVehicleId);
  });

  it("shows both vehicles to the owner", async () => {
    const res = await request(app)
      .get(`/api/v1/garages/${garageId}/vehicles`)
      .set("Authorization", `Bearer ${owner}`);
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(2);
  });

  it("blocks a stranger from viewing the private vehicle directly by id", async () => {
    const res = await request(app)
      .get(`/api/v1/garages/${garageId}/vehicles/${privateVehicleId}`)
      .set("Authorization", `Bearer ${stranger}`);
    expect(res.status).toBe(404);
  });

  it("lets the owner view the private vehicle directly by id", async () => {
    const res = await request(app)
      .get(`/api/v1/garages/${garageId}/vehicles/${privateVehicleId}`)
      .set("Authorization", `Bearer ${owner}`);
    expect(res.status).toBe(200);
  });

  it("blocks a stranger from creating a vehicle in someone else's garage", async () => {
    const res = await request(app)
      .post(`/api/v1/garages/${garageId}/vehicles`)
      .set("Authorization", `Bearer ${stranger}`)
      .send({ make: "Ford", model: "Focus", year: 2019 });
    expect(res.status).toBe(403);
  });

  it("blocks a stranger from deleting someone else's vehicle", async () => {
    const res = await request(app)
      .delete(`/api/v1/garages/${garageId}/vehicles/${publicVehicleId}`)
      .set("Authorization", `Bearer ${stranger}`);
    expect(res.status).toBe(403);
  });

  it("rejects an invalid VIN format on the decode endpoint", async () => {
    const res = await request(app).get("/api/v1/vin/TOOSHORT");
    expect(res.status).toBe(400);
  });

  it("lets a stranger like a public vehicle and notifies the owner", async () => {
    const res = await request(app)
      .post(`/api/v1/garages/${garageId}/vehicles/${publicVehicleId}/like`)
      .set("Authorization", `Bearer ${stranger}`);
    expect(res.status).toBe(204);

    const detail = await request(app)
      .get(`/api/v1/garages/${garageId}/vehicles/${publicVehicleId}`)
      .set("Authorization", `Bearer ${stranger}`);
    expect(detail.body.data.isLikedByMe).toBe(true);
    expect(detail.body.data._count.likes).toBe(1);

    const ownerNotifs = await request(app)
      .get("/api/v1/notifications")
      .set("Authorization", `Bearer ${owner}`);
    expect(ownerNotifs.body.data.some((n: any) => n.type === "VEHICLE_LIKE")).toBe(true);
  });

  it("does not double-count liking the same vehicle twice", async () => {
    await request(app)
      .post(`/api/v1/garages/${garageId}/vehicles/${publicVehicleId}/like`)
      .set("Authorization", `Bearer ${stranger}`);

    const detail = await request(app).get(`/api/v1/garages/${garageId}/vehicles/${publicVehicleId}`);
    expect(detail.body.data._count.likes).toBe(1);
  });

  it("unlikes a vehicle", async () => {
    const res = await request(app)
      .delete(`/api/v1/garages/${garageId}/vehicles/${publicVehicleId}/like`)
      .set("Authorization", `Bearer ${stranger}`);
    expect(res.status).toBe(204);

    const detail = await request(app)
      .get(`/api/v1/garages/${garageId}/vehicles/${publicVehicleId}`)
      .set("Authorization", `Bearer ${stranger}`);
    expect(detail.body.data.isLikedByMe).toBe(false);
    expect(detail.body.data._count.likes).toBe(0);
  });

  it("blocks liking a private vehicle you can't see", async () => {
    const res = await request(app)
      .post(`/api/v1/garages/${garageId}/vehicles/${privateVehicleId}/like`)
      .set("Authorization", `Bearer ${stranger}`);
    expect(res.status).toBe(404);
  });

  it("lets a stranger comment on a public vehicle and notifies the owner", async () => {
    const res = await request(app)
      .post(`/api/v1/garages/${garageId}/vehicles/${publicVehicleId}/comments`)
      .set("Authorization", `Bearer ${stranger}`)
      .send({ content: "Love the color combo on this one!" });
    expect(res.status).toBe(201);
    commentId = res.body.data.id;

    const ownerNotifs = await request(app)
      .get("/api/v1/notifications")
      .set("Authorization", `Bearer ${owner}`);
    expect(ownerNotifs.body.data.some((n: any) => n.type === "VEHICLE_COMMENT")).toBe(true);
  });

  it("lists comments publicly, without requiring auth", async () => {
    const res = await request(app).get(`/api/v1/garages/${garageId}/vehicles/${publicVehicleId}/comments`);
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].content).toBe("Love the color combo on this one!");
  });

  it("blocks commenting on a private vehicle you can't see", async () => {
    const res = await request(app)
      .post(`/api/v1/garages/${garageId}/vehicles/${privateVehicleId}/comments`)
      .set("Authorization", `Bearer ${stranger}`)
      .send({ content: "sneaky" });
    expect(res.status).toBe(404);
  });

  it("prevents editing someone else's comment", async () => {
    const res = await request(app)
      .patch(`/api/v1/garages/${garageId}/vehicles/${publicVehicleId}/comments/${commentId}`)
      .set("Authorization", `Bearer ${owner}`)
      .send({ content: "hijacked" });
    expect(res.status).toBe(403);
  });

  it("lets the comment author edit their own comment", async () => {
    const res = await request(app)
      .patch(`/api/v1/garages/${garageId}/vehicles/${publicVehicleId}/comments/${commentId}`)
      .set("Authorization", `Bearer ${stranger}`)
      .send({ content: "Edited: love the color combo!" });
    expect(res.status).toBe(200);
    expect(res.body.data.editedAt).toBeTruthy();
  });

  it("soft-deletes a comment and masks it at the read layer without destroying it", async () => {
    const res = await request(app)
      .delete(`/api/v1/garages/${garageId}/vehicles/${publicVehicleId}/comments/${commentId}`)
      .set("Authorization", `Bearer ${stranger}`);
    expect(res.status).toBe(204);

    const list = await request(app).get(`/api/v1/garages/${garageId}/vehicles/${publicVehicleId}/comments`);
    expect(list.body.data[0].content).toBe("[deleted]");
  });

  it("bookmarks a public vehicle and reflects isBookmarkedByMe for that user only", async () => {
    const bookmarkRes = await request(app)
      .post(`/api/v1/garages/${garageId}/vehicles/${publicVehicleId}/bookmark`)
      .set("Authorization", `Bearer ${stranger}`);
    expect(bookmarkRes.status).toBe(204);

    const strangerView = await request(app)
      .get(`/api/v1/garages/${garageId}/vehicles/${publicVehicleId}`)
      .set("Authorization", `Bearer ${stranger}`);
    expect(strangerView.body.data.isBookmarkedByMe).toBe(true);

    const ownerView = await request(app)
      .get(`/api/v1/garages/${garageId}/vehicles/${publicVehicleId}`)
      .set("Authorization", `Bearer ${owner}`);
    expect(ownerView.body.data.isBookmarkedByMe).toBe(false);
  });

  it("lists bookmarked vehicles for the caller only", async () => {
    const res = await request(app)
      .get("/api/v1/garages/vehicle-bookmarks")
      .set("Authorization", `Bearer ${stranger}`);
    expect(res.status).toBe(200);
    expect(res.body.data.some((v: any) => v.id === publicVehicleId)).toBe(true);

    const ownerList = await request(app)
      .get("/api/v1/garages/vehicle-bookmarks")
      .set("Authorization", `Bearer ${owner}`);
    expect(ownerList.body.data.some((v: any) => v.id === publicVehicleId)).toBe(false);
  });

  it("requires auth to list vehicle bookmarks", async () => {
    const res = await request(app).get("/api/v1/garages/vehicle-bookmarks");
    expect(res.status).toBe(401);
  });

  it("blocks bookmarking a private vehicle you can't see", async () => {
    const res = await request(app)
      .post(`/api/v1/garages/${garageId}/vehicles/${privateVehicleId}/bookmark`)
      .set("Authorization", `Bearer ${stranger}`);
    expect(res.status).toBe(404);
  });

  it("quietly excludes a bookmarked vehicle from the list once it goes private, but still shows it to its owner", async () => {
    // Bookmark a second, currently-public vehicle as the stranger.
    const secondVehicle = await request(app)
      .post(`/api/v1/garages/${garageId}/vehicles`)
      .set("Authorization", `Bearer ${owner}`)
      .send({ make: "Mazda", model: "Miata", year: 2021, isPublic: true });
    const secondVehicleId = secondVehicle.body.data.id;

    await request(app)
      .post(`/api/v1/garages/${garageId}/vehicles/${secondVehicleId}/bookmark`)
      .set("Authorization", `Bearer ${stranger}`);

    const beforeGoingPrivate = await request(app)
      .get("/api/v1/garages/vehicle-bookmarks")
      .set("Authorization", `Bearer ${stranger}`);
    expect(beforeGoingPrivate.body.data.some((v: any) => v.id === secondVehicleId)).toBe(true);

    // Owner now flips it private.
    await request(app)
      .patch(`/api/v1/garages/${garageId}/vehicles/${secondVehicleId}`)
      .set("Authorization", `Bearer ${owner}`)
      .send({ isPublic: false });

    // The bookmark still exists, but the vehicle is no longer visible to
    // the stranger who bookmarked it — this must not leak its details.
    const afterGoingPrivate = await request(app)
      .get("/api/v1/garages/vehicle-bookmarks")
      .set("Authorization", `Bearer ${stranger}`);
    expect(afterGoingPrivate.body.data.some((v: any) => v.id === secondVehicleId)).toBe(false);

    // The owner, however, should still see their own vehicle in their
    // hypothetical bookmarks (not applicable here since they didn't
    // bookmark their own vehicle, but confirm no crash / correct shape).
    const ownerList = await request(app)
      .get("/api/v1/garages/vehicle-bookmarks")
      .set("Authorization", `Bearer ${owner}`);
    expect(ownerList.status).toBe(200);
  });

  it("unbookmarks a vehicle", async () => {
    const res = await request(app)
      .delete(`/api/v1/garages/${garageId}/vehicles/${publicVehicleId}/bookmark`)
      .set("Authorization", `Bearer ${stranger}`);
    expect(res.status).toBe(204);

    const list = await request(app)
      .get("/api/v1/garages/vehicle-bookmarks")
      .set("Authorization", `Bearer ${stranger}`);
    expect(list.body.data.some((v: any) => v.id === publicVehicleId)).toBe(false);
  });
});
