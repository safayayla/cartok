import { NextFunction, Request, Response } from "express";
import { AnyZodObject, ZodEffects } from "zod";

type Schema = AnyZodObject | ZodEffects<AnyZodObject>;

// Validates and *replaces* body/query/params with the parsed, coerced,
// stripped-of-unknown-keys result — this is the app's SQL-injection/XSS
// first line of defense: nothing unvalidated ever reaches a Prisma call.
export function validate(schema: { body?: Schema; query?: Schema; params?: Schema }) {
  return (req: Request, _res: Response, next: NextFunction) => {
    if (schema.body) req.body = schema.body.parse(req.body);
    if (schema.query) req.query = schema.query.parse(req.query) as typeof req.query;
    if (schema.params) req.params = schema.params.parse(req.params) as typeof req.params;
    next();
  };
}
