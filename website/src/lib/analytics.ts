"use client";

const apiKey = process.env.NEXT_PUBLIC_AMPLITUDE_API_KEY;

export function track(eventType: string, props?: Record<string, string | boolean>) {
  if (typeof window === "undefined" || localStorage.getItem("bloom-site-analytics-consent") !== "accepted" || !apiKey) return;
  const allowed = new Set(["homepage_cta_clicked", "download_cta_clicked", "platform_selected", "ios_waitlist_viewed", "waitlist_submission_attempted", "waitlist_submission_succeeded", "waitlist_beta_interest_selected", "waitlist_form_error", "faq_opened"]);
  if (!allowed.has(eventType)) return;
  const payload = { api_key: apiKey, events: [{ event_type: eventType, event_properties: props ?? {}, session_id: Date.now(), time: Date.now() }] };
  void fetch("https://api2.amplitude.com/2/httpapi", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload), keepalive: true }).catch(() => undefined);
}
