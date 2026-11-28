import { consumeLimit, readJson, responseJson } from "@/lib/http";
import { hmacHex, trustedClientAddress } from "@/lib/server-security";
import { sendSupportMessage } from "@/lib/mail";
import { boundedText, isRecord, normalizeEmail } from "@/lib/validation";

export const runtime = "nodejs";
const topics = new Set(["general", "account", "deletion", "privacy", "family", "accessibility", "other"]);

export async function POST(request: Request) {
  try {
    const input = await readJson(request);
    if (!isRecord(input)) return responseJson(400, { error: "Check each field and try again." });
    if (typeof input.company === "string" && input.company.trim()) return responseJson(202, { message: "Thanks. If the message can be delivered, Bloom support has received it." });
    const name = boundedText(input.name, 100);
    const email = normalizeEmail(input.email);
    const message = boundedText(input.message, 3000);
    const topic = typeof input.topic === "string" ? input.topic : "";
    if (!name || !email || !message || !topics.has(topic)) return responseJson(400, { error: "Enter a valid name, email, topic and message." });
    const address = trustedClientAddress(request);
    const [ipAllowed, emailAllowed] = await Promise.all([
      consumeLimit(hmacHex(`contact-ip:${address}`), 5, 3600),
      consumeLimit(hmacHex(`contact-email:${email}`), 3, 3600),
    ]);
    if (!ipAllowed || !emailAllowed) return responseJson(429, { error: "Please wait a little before sending another message." });
    await sendSupportMessage({ name, email, topic, message });
    return responseJson(202, { message: "Your message was sent to Bloom support." });
  } catch {
    return responseJson(503, { error: "Support email is temporarily unavailable. Try again later or use in-app support." });
  }
}
