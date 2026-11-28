"use client";

import { FormEvent, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";

type Preferences = { beta_interest: boolean; marketing_consent: boolean };

function RequestLink() {
  const [email, setEmail] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  async function submit(event: FormEvent) {
    event.preventDefault(); setBusy(true); setMessage("");
    const response = await fetch("/api/waitlist/manage-link", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ email }) }).catch(() => null);
    const body = response ? await response.json().catch(() => ({})) : {};
    setMessage(response?.ok ? body.message : body.error ?? "The request could not be sent. Try again later."); setBusy(false);
  }
  return <form className="contact-form" onSubmit={submit}><p>Enter the address you used for Bloom launch updates. We’ll email a secure link if it has a confirmed request. The form doesn’t reveal whether an address is registered.</p><label htmlFor="manage-email">Email address</label><input id="manage-email" type="email" required maxLength={254} autoComplete="email" value={email} onChange={(event) => setEmail(event.target.value)}/><button className="button button-dark" disabled={busy}>{busy ? "Sending…" : "Email me a secure link"}</button><p className="form-result" aria-live="polite">{message}</p></form>;
}

function ManageWithToken({ token }: { token: string }) {
  const [preferences, setPreferences] = useState<Preferences | null>(null);
  const [beta, setBeta] = useState(false);
  const [marketing, setMarketing] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);
  useEffect(() => { void fetch("/api/waitlist/manage/preferences", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ token }) }).then(async (response) => ({ ok: response.ok, body: await response.json() })).then(({ ok, body }) => { if (!ok) throw new Error(body.error); setPreferences(body as Preferences); setBeta(body.beta_interest); setMarketing(body.marketing_consent); }).catch((error: unknown) => setStatus(error instanceof Error ? error.message : "This link is invalid or expired.")); }, [token]);
  async function perform(action: "update" | "unsubscribe" | "delete") {
    setBusy(true); setStatus("");
    const response = await fetch("/api/waitlist/manage", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ token, action, beta_interest: beta, marketing_consent: marketing, confirm_delete: confirmDelete }) }).catch(() => null);
    const body = response ? await response.json().catch(() => ({})) : {};
    setStatus(response?.ok ? body.message : body.error ?? "Could not update these preferences.");
    if (response?.ok) setPreferences(null);
    setBusy(false);
  }
  if (!preferences) return <div className="notice-card" role="status">{status || "Checking this private link…"}</div>;
  return <div className="manage-form"><p>These optional choices are separate from the launch update you requested.</p><label className="consent-option"><input type="checkbox" checked={beta} onChange={(event) => setBeta(event.target.checked)}/><span><b>Consider me for the iPhone beta.</b><small>Invitations are selective and not guaranteed. Complimentary access, if offered, is only during testing.</small></span></label><label className="consent-option"><input type="checkbox" checked={marketing} onChange={(event) => setMarketing(event.target.checked)}/><span><b>Email me occasional Bloom product news.</b><small>Optional marketing messages. Launch updates are separate.</small></span></label><div className="manage-actions"><button className="button button-dark" onClick={() => perform("update")} disabled={busy}>{busy ? "Saving…" : "Save preferences"}</button><button className="text-link" onClick={() => perform("unsubscribe")} disabled={busy}>Stop all Bloom emails</button></div><div className="delete-waitlist"><label className="consent-option"><input type="checkbox" checked={confirmDelete} onChange={(event) => setConfirmDelete(event.target.checked)}/><span>Delete my iPhone waitlist information.</span></label><button className="button button-danger" onClick={() => perform("delete")} disabled={!confirmDelete || busy}>Delete my waitlist details</button></div><p className="form-result" role="status">{status}</p></div>;
}

export function WaitlistManagement() {
  const params = useSearchParams();
  const token = params.get("token");
  return <div className="manage-layout page-width"><section className="page-hero"><p className="eyebrow">Your list, your choice</p><h1>Manage Bloom<br/><em>updates.</em></h1><p className="page-lede">Change your optional preferences, stop all emails, or delete your launch-list details.</p></section><section className="manage-content">{token ? <ManageWithToken token={token}/> : <RequestLink/>}</section></div>;
}
