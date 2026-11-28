"use client";

import { useEffect, useState } from "react";
import { track } from "@/lib/analytics";

export function CookieConsent() {
  const [visible, setVisible] = useState(false);
  useEffect(() => { setVisible(localStorage.getItem("bloom-site-analytics-consent") === null); }, []);
  function choose(value: "accepted" | "rejected") {
    localStorage.setItem("bloom-site-analytics-consent", value);
    setVisible(false);
    if (value === "accepted") track("website_analytics_consent", { choice: "accepted" });
  }
  if (!visible) return null;
  return <aside className="consent-banner" aria-label="Optional analytics settings">
    <div><strong>Your visit, your choice.</strong><p>Bloom keeps optional website analytics off unless you allow them. No advertising cookies are used.</p></div>
    <div className="consent-actions"><button className="button button-small button-quiet" onClick={() => choose("rejected")}>Keep off</button><button className="button button-small button-dark" onClick={() => choose("accepted")}>Allow analytics</button></div>
  </aside>;
}
