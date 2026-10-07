import { z } from "zod";

const passwordSchema = z
  .string()
  .min(10, "Password must be at least 10 characters")
  .max(128)
  .regex(/[a-z]/, "Password needs a lowercase letter")
  .regex(/[A-Z]/, "Password needs an uppercase letter")
  .regex(/[0-9]/, "Password needs a number");

const usernameSchema = z
  .string()
  .min(3)
  .max(24)
  .regex(/^[a-z0-9_.]+$/, "Username can only contain lowercase letters, numbers, underscores, and dots");

const registerBody = z.object({
  email: z.string().email().max(254).toLowerCase(),
  username: usernameSchema,
  password: passwordSchema,
  displayName: z.string().min(1).max(60),
});

const loginBody = z.object({
  email: z.string().email().max(254).toLowerCase(),
  password: z.string().min(1).max(128),
});

const refreshBody = z.object({
  refreshToken: z.string().min(20).optional(), // may also arrive via httpOnly cookie
});

// Each export is a { body?, query?, params? } bundle consumed by the
// `validate()` middleware — never a bare z.object, so field access stays type-safe.
export const registerSchema = { body: registerBody };
export const loginSchema = { body: loginBody };
export const refreshSchema = { body: refreshBody };

export type RegisterInput = z.infer<typeof registerBody>;
export type LoginInput = z.infer<typeof loginBody>;
