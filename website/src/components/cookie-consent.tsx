"use client";

import { useSyncExternalStore } from "react";
import { track } from "@/lib/analytics";

const CONSENT_KEY = "bloom-site-analytics-consent";
const CONSENT_CHANGE_EVENT = "bloom-site-analytics-consent-change";

function subscribe(callback: () => void) {
  window.addEventListener("storage", callback);
  window.addEventListener(CONSENT_CHANGE_EVENT, callback);
  return () => {
    window.removeEventListener("storage", callback);
    window.removeEventListener(CONSENT_CHANGE_EVENT, callback);
  };
}

function getSnapshot() {
  return localStorage.getItem(CONSENT_KEY);
}

export function CookieConsent() {
  const consent = useSyncExternalStore(subscribe, getSnapshot, () => "unknown");
  const visible = consent === null;

  function choose(value: "accepted" | "rejected") {
    localStorage.setItem(CONSENT_KEY, value);
    window.dispatchEvent(new Event(CONSENT_CHANGE_EVENT));
    if (value === "accepted") track("website_analytics_consent", { choice: "accepted" });
  }
  if (!visible) return null;
  return <aside className="consent-banner" aria-label="Optional analytics settings">
    <div><strong>Your visit, your choice.</strong><p>Bloom keeps optional website analytics off unless you allow them. No advertising cookies are used.</p></div>
    <div className="consent-actions"><button className="button button-small button-quiet" onClick={() => choose("rejected")}>Keep off</button><button className="button button-small button-dark" onClick={() => choose("accepted")}>Allow analytics</button></div>
  </aside>;
}
