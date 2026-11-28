"use client";

import { Suspense, useState } from "react";
import { useSearchParams } from "next/navigation";

function VerifyForm() {
  const params = useSearchParams();
  const token = params.get("token") ?? "";
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  async function confirm() {
    setBusy(true);
    const response = await fetch("/api/waitlist/confirm", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ token }) }).catch(() => null);
    const result = response ? await response.json().catch(() => ({})) : {};
    setMessage(response?.ok ? result.message : result.error ?? "We couldn’t verify this link. Request a new confirmation and try again.");
    setBusy(false);
  }
  return <div className="centered-message page-width"><p className="eyebrow">Confirm your email</p><h1>One small<br/><em>last step.</em></h1><p className="page-lede">Select below to verify this address and receive Bloom launch updates.</p>{message ? <div role="status" className="form-result">{message}</div> : <button className="button button-dark" onClick={confirm} disabled={!token || busy}>{busy ? "Confirming…" : "Confirm launch updates"}</button>}</div>;
}

export default function VerifyPage() { return <Suspense fallback={<div className="centered-message page-width">Loading confirmation…</div>}><VerifyForm/></Suspense>; }
