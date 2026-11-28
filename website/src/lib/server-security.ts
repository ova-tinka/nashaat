import "server-only";
import { createHmac, timingSafeEqual, randomUUID } from "node:crypto";

function keyFor(name: string) {
  const key = process.env[name];
  if (!key || Buffer.byteLength(key) < 32) throw new Error(`${name} must contain at least 32 bytes`);
  return key;
}

export function hmacHex(value: string, keyName = "BLOOM_RATE_LIMIT_SECRET") {
  return createHmac("sha256", keyFor(keyName)).update(value, "utf8").digest("hex");
}

export function newGeneration() { return randomUUID(); }

export function signToken(data: { id: string; generation: string; purpose: "confirm" | "manage"; exp: number }) {
  const payload = Buffer.from(JSON.stringify(data)).toString("base64url");
  const signature = createHmac("sha256", keyFor("BLOOM_LINK_SIGNING_SECRET")).update(payload).digest("base64url");
  return `${payload}.${signature}`;
}

export function verifyToken(token: unknown, purpose: "confirm" | "manage") {
  if (typeof token !== "string" || token.length > 2048) return null;
  const [payload, signature, extra] = token.split(".");
  if (!payload || !signature || extra) return null;
  let expected: Buffer;
  let supplied: Buffer;
  try {
    expected = createHmac("sha256", keyFor("BLOOM_LINK_SIGNING_SECRET")).update(payload).digest();
    supplied = Buffer.from(signature, "base64url");
  } catch { return null; }
  if (expected.length !== supplied.length || !timingSafeEqual(expected, supplied)) return null;
  try {
    const data: unknown = JSON.parse(Buffer.from(payload, "base64url").toString("utf8"));
    if (typeof data !== "object" || !data || !("id" in data) || !("generation" in data) || !("purpose" in data) || !("exp" in data)) return null;
    const value = data as { id: unknown; generation: unknown; purpose: unknown; exp: unknown };
    if (typeof value.id !== "string" || !/^[0-9a-f-]{36}$/iu.test(value.id)) return null;
    if (typeof value.generation !== "string" || !/^[0-9a-f-]{36}$/iu.test(value.generation)) return null;
    if (value.purpose !== purpose || typeof value.exp !== "number" || value.exp <= Date.now()) return null;
    return { id: value.id, generation: value.generation, exp: value.exp };
  } catch { return null; }
}

export function trustedClientAddress(request: Request) {
  const trusted = request.headers.get("x-vercel-forwarded-for") ?? request.headers.get("x-real-ip") ?? "unknown";
  const candidate = trusted.split(",", 1)[0].trim();
  return candidate.length <= 80 && /^[0-9a-f:.]+$/iu.test(candidate) ? candidate : "unknown";
}
