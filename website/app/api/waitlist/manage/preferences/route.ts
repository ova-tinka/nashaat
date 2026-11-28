import { readJson, responseJson } from "@/lib/http";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { verifyToken } from "@/lib/server-security";
import { isRecord } from "@/lib/validation";

export const runtime = "nodejs";
export async function POST(request: Request) {
  try {
    const input = await readJson(request);
    if (!isRecord(input)) return responseJson(400, { error: "This management link is invalid or expired." });
    const token = verifyToken(input.token, "manage");
    if (!token) return responseJson(400, { error: "This management link is invalid or expired." });
    const { data, error } = await supabaseAdmin().rpc("bloom_website_get_preferences", { p_id: token.id, p_generation: token.generation });
    if (error) return responseJson(503, { error: "Bloom couldn’t load these preferences right now." });
    if (!isRecord(data) || typeof data.beta_interest !== "boolean" || typeof data.marketing_consent !== "boolean") return responseJson(400, { error: "This management link is invalid or expired. Request a new one." });
    return responseJson(200, { beta_interest: data.beta_interest, marketing_consent: data.marketing_consent });
  } catch { return responseJson(503, { error: "Bloom couldn’t load these preferences right now." }); }
}
