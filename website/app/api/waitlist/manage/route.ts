import { readJson, responseJson } from "@/lib/http";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { verifyToken } from "@/lib/server-security";
import { isRecord, CONSENT_POLICY_VERSION } from "@/lib/validation";

export const runtime = "nodejs";
export async function POST(request: Request) {
  try {
    const input = await readJson(request);
    if (!isRecord(input) || typeof input.action !== "string") return responseJson(400, { error: "Choose a valid preference update." });
    const token = verifyToken(input.token, "manage");
    if (!token) return responseJson(400, { error: "This management link is invalid or expired. Request a new one." });
    const action = input.action;
    if (!(["update", "unsubscribe", "delete"] as const).includes(action as "update" | "unsubscribe" | "delete")) return responseJson(400, { error: "Choose a valid preference update." });
    if (action === "update" && (typeof input.beta_interest !== "boolean" || typeof input.marketing_consent !== "boolean")) return responseJson(400, { error: "Choose both optional preferences." });
    if (action === "delete" && input.confirm_delete !== true) return responseJson(400, { error: "Confirm deletion of the waitlist details." });
    const { data, error } = await supabaseAdmin().rpc("bloom_website_manage", {
      p_id: token.id,
      p_generation: token.generation,
      p_action: action,
      p_beta_interest: action === "update" && input.beta_interest === true,
      p_marketing_consent: action === "update" && input.marketing_consent === true,
      p_policy_version: CONSENT_POLICY_VERSION,
    });
    if (error) return responseJson(503, { error: "Bloom couldn’t update those details right now. Please try again." });
    if (data !== true) return responseJson(400, { error: "This management link is no longer valid. Request a new one." });
    const message = action === "delete" ? "Your iPhone waitlist details have been deleted." : action === "unsubscribe" ? "Your Bloom emails have been stopped." : "Your optional preferences have been updated.";
    return responseJson(200, { message });
  } catch { return responseJson(503, { error: "Bloom couldn’t update those details right now. Please try again." }); }
}
