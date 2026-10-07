import { env } from "../config/env";
import { Errors } from "../middleware/errors";
import { logger } from "../config/logger";

export interface DecodedVin {
  vin: string;
  make?: string;
  model?: string;
  modelYear?: string;
  trim?: string;
  bodyClass?: string;
  engineCylinders?: string;
  fuelType?: string;
  driveType?: string;
  raw: Record<string, string>;
}

const VIN_REGEX = /^[A-HJ-NPR-Z0-9]{17}$/i; // excludes I, O, Q per VIN spec

export function isValidVinFormat(vin: string): boolean {
  return VIN_REGEX.test(vin);
}

// Decodes a VIN via NHTSA's free public vPIC API (no key required).
// This is informational/enrichment data only — never treated as a source
// of truth for legal ownership or safety-critical decisions.
export async function decodeVin(vin: string): Promise<DecodedVin> {
  if (!isValidVinFormat(vin)) {
    throw Errors.badRequest("Invalid VIN format — must be 17 characters (no I, O, Q)");
  }

  const url = `${env.NHTSA_VIN_API_BASE}/decodevin/${encodeURIComponent(vin)}?format=json`;

  let response: globalThis.Response;
  try {
    response = await fetch(url, { signal: AbortSignal.timeout(8000) });
  } catch (err) {
    logger.error({ err, vin }, "VIN decode request failed");
    throw Errors.internal("VIN decoding service is currently unavailable");
  }

  if (!response.ok) {
    throw Errors.internal("VIN decoding service returned an error");
  }

  const body = (await response.json()) as { Results?: Array<{ Variable: string; Value: string | null }> };
  const results = body.Results ?? [];

  const lookup = (variable: string) =>
    results.find((r) => r.Variable === variable)?.Value?.trim() || undefined;

  const raw: Record<string, string> = {};
  for (const r of results) {
    if (r.Value) raw[r.Variable] = r.Value;
  }

  return {
    vin: vin.toUpperCase(),
    make: lookup("Make"),
    model: lookup("Model"),
    modelYear: lookup("Model Year"),
    trim: lookup("Trim"),
    bodyClass: lookup("Body Class"),
    engineCylinders: lookup("Engine Number of Cylinders"),
    fuelType: lookup("Fuel Type - Primary"),
    driveType: lookup("Drive Type"),
    raw,
  };
}
