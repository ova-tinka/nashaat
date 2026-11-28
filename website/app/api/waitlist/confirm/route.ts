import { readJson, responseJson } from "@/lib/http";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { verifyToken } from "@/lib/server-security";
import { isRecord } from "@/lib/validation";

export const runtime = "nodejs";
export async function POST(request: Request) {
  try {
    const input = await readJson(request);
    if (!isRecord(input)) return responseJson(400, { error: "This confirmation link is invalid or expired. Request a new one." });
    const token = verifyToken(input.token, "confirm");
    if (!token) return responseJson(400, { error: "This confirmation link is invalid or expired. Request a new one." });
    const { data, error } = await supabaseAdmin().rpc("bloom_website_confirm_waitlist", { p_id: token.id, p_generation: token.generation });
    if (error) return responseJson(503, { error: "Bloom couldn’t confirm this request right now. Please try again." });
    if (data !== true) return responseJson(400, { error: "This confirmation link is invalid, expired or already used. Request a new one if needed." });
    return responseJson(200, { message: "Your email is confirmed. We’ll send the iPhone launch update you requested." });
  } catch { return responseJson(503, { error: "Bloom couldn’t confirm this request right now. Please try again." }); }
}
