import "server-only";
import { readBoundedJson } from "@/lib/bounded-json";

export function responseJson(status: number, body: Record<string, unknown>) {
  return Response.json(body, { status, headers: { "Cache-Control": "no-store", "Referrer-Policy": "no-referrer" } });
}

export async function readJson(request: Request): Promise<unknown> {
  return readBoundedJson(request);
}

export function publicOrigin() {
  const value = process.env.NEXT_PUBLIC_BLOOM_SITE_URL;
  if (!value) throw new Error("Public site origin is not configured");
  const url = new URL(value);
  const localDevelopment = process.env.NODE_ENV !== "production" && ["localhost", "127.0.0.1"].includes(url.hostname);
  if (url.origin !== value.replace(/\/$/, "") || (url.protocol !== "https:" && !localDevelopment)) throw new Error("Invalid public site origin");
  return url.origin;
}

export async function consumeLimit(fingerprint: string, limit: number, seconds: number) {
  const { data, error } = await (await import("@/lib/supabase-admin")).supabaseAdmin().rpc("bloom_website_consume_rate_limit", { p_fingerprint: fingerprint, p_limit: limit, p_window_seconds: seconds });
  if (error) throw error;
  return data === true;
}
