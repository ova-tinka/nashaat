import { consumeLimit, publicOrigin, readJson, responseJson } from "@/lib/http";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { hmacHex, newGeneration, signToken, trustedClientAddress } from "@/lib/server-security";
import { sendWaitlistConfirmation } from "@/lib/mail";
import { isRecord, normalizeEmail, CONSENT_POLICY_VERSION } from "@/lib/validation";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const input = await readJson(request);
    if (!isRecord(input)) return responseJson(400, { error: "Check the form and try again." });
    if (typeof input.website === "string" && input.website.trim()) return responseJson(202, { message: "If the request needs confirmation, check your inbox for the next step." });
    const email = normalizeEmail(input.email);
    if (!email || input.adult !== true) return responseJson(400, { error: "Enter a valid email and confirm that you are an adult or guardian." });
    if (input.beta_interest !== undefined && typeof input.beta_interest !== "boolean") return responseJson(400, { error: "Check the form and try again." });
    if (input.marketing_consent !== undefined && typeof input.marketing_consent !== "boolean") return responseJson(400, { error: "Check the form and try again." });

    const origin = publicOrigin();
    const address = trustedClientAddress(request);
    const [ipAllowed, emailAllowed] = await Promise.all([
      consumeLimit(hmacHex(`ip:${address}`), 15, 3600),
      consumeLimit(hmacHex(`waitlist:${email}`), 5, 3600),
    ]);
    if (!ipAllowed || !emailAllowed) return responseJson(429, { error: "Please wait a little before trying again." });

    const generation = newGeneration();
    const emailFingerprint = hmacHex(`waitlist-lock:${email}`);
    const { data, error } = await supabaseAdmin().rpc("bloom_website_start_waitlist", {
      p_email: email,
      p_email_fingerprint: emailFingerprint,
      p_generation: generation,
      p_beta_interest: input.beta_interest === true,
      p_marketing_consent: input.marketing_consent === true,
      p_adult_or_guardian: true,
      p_policy_version: CONSENT_POLICY_VERSION,
    });
    if (error || !isRecord(data)) return responseJson(503, { error: "Bloom couldn’t save the request right now. Please try again later." });
    if (data.should_send === true && typeof data.id === "string") {
      if (typeof data.generation !== "string") return responseJson(503, { error: "Bloom couldn’t prepare a confirmation right now. Please try again later." });
      const token = signToken({ id: data.id, generation: data.generation, purpose: "confirm", exp: Date.now() + 48 * 60 * 60 * 1000 });
      const confirmationUrl = `${origin}/ios/verify?token=${encodeURIComponent(token)}`;
      const managementUrl = `${origin}/ios/manage`;
      try {
        await sendWaitlistConfirmation(email, confirmationUrl, managementUrl);
        await supabaseAdmin().rpc("bloom_website_mark_waitlist_email_sent", { p_id: data.id, p_generation: data.generation });
      } catch {
        return responseJson(503, { error: "Bloom saved the request, but couldn’t send its confirmation yet. Please try again in a few minutes." });
      }
    }
    return responseJson(202, { message: "If your request needs confirmation, check your inbox for the next step. Bloom adds an address only after it is confirmed." });
  } catch {
    return responseJson(503, { error: "The waitlist is temporarily unavailable. Please try again later." });
  }
}
