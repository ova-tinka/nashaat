import { consumeLimit, publicOrigin, readJson, responseJson } from "@/lib/http";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { hmacHex, newGeneration, signToken, trustedClientAddress } from "@/lib/server-security";
import { sendManagementLink } from "@/lib/mail";
import { isRecord, normalizeEmail } from "@/lib/validation";

export const runtime = "nodejs";
const genericMessage = "If a confirmed Bloom waitlist request matches that address, a secure management link will be sent.";

export async function POST(request: Request) {
  try {
    const input = await readJson(request);
    if (!isRecord(input)) return responseJson(400, { error: "Enter a valid email address." });
    if (typeof input.website === "string" && input.website.trim()) return responseJson(202, { message: genericMessage });
    const email = normalizeEmail(input.email);
    if (!email) return responseJson(400, { error: "Enter a valid email address." });
    const origin = publicOrigin();
    const ip = trustedClientAddress(request);
    const [ipAllowed, emailAllowed] = await Promise.all([
      consumeLimit(hmacHex(`manage-ip:${ip}`), 10, 3600),
      consumeLimit(hmacHex(`manage-email:${email}`), 3, 3600),
    ]);
    if (!ipAllowed || !emailAllowed) return responseJson(429, { error: "Please wait a little before trying again." });
    const generation = newGeneration();
    const { data, error } = await supabaseAdmin().rpc("bloom_website_start_management", { p_email: email, p_generation: generation });
    if (error) return responseJson(503, { error: "Bloom couldn’t send that request right now. Please try again later." });
    if (isRecord(data) && data.found === true && typeof data.id === "string" && typeof data.generation === "string" && typeof data.email === "string") {
      const token = signToken({ id: data.id, generation: data.generation, purpose: "manage", exp: Date.now() + 30 * 60 * 1000 });
      try { await sendManagementLink(data.email, `${origin}/ios/manage?token=${encodeURIComponent(token)}`); }
      catch { return responseJson(503, { error: "Bloom couldn’t send that request right now. Please try again later." }); }
    }
    return responseJson(202, { message: genericMessage });
  } catch { return responseJson(503, { error: "Bloom couldn’t send that request right now. Please try again later." }); }
}
