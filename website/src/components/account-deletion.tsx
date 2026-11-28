"use client";

import { FormEvent, useEffect, useState } from "react";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

type DeletionStatus = { status?: string; error?: string; code?: string };
let client: SupabaseClient | null = null;
function supabase() {
  if (client) return client;
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) throw new Error("The sign-in service is not configured yet.");
  client = createClient(url, key, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } });
  return client;
}

export function AccountDeletion() {
  const [configured, setConfigured] = useState(false);
  const [signedInEmail, setSignedInEmail] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmed, setConfirmed] = useState(false);
  const [status, setStatus] = useState<DeletionStatus | null>(null);
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    try {
      const auth = supabase(); setConfigured(true);
      void auth.auth.getSession().then(({ data }) => setSignedInEmail(data.session?.user.email ?? ""));
    } catch { setConfigured(false); }
  }, []);
  async function signIn(event: FormEvent) {
    event.preventDefault(); setBusy(true); setStatus(null);
    try {
      const { data, error } = await supabase().auth.signInWithPassword({ email: email.trim(), password });
      if (error) throw error;
      setSignedInEmail(data.user.email ?? email.trim()); setPassword("");
      setStatus({ status: "signed_in" });
    } catch { setStatus({ error: "Sign-in failed. Check the address and password, then try again." }); }
    finally { setBusy(false); }
  }
  async function requestDeletion() {
    if (!confirmed || busy) return;
    setBusy(true); setStatus(null);
    try {
      const { data, error } = await supabase().functions.invoke<DeletionStatus>("bloom-account-delete", { body: {} });
      if (error) {
        const detail = await error.context?.json?.().catch(() => null);
        if (detail && typeof detail === "object") setStatus(detail as DeletionStatus);
        else throw error;
      } else setStatus(data);
      if (data?.status === "completed") {
        await supabase().auth.signOut(); setSignedInEmail("");
      }
    } catch { setStatus({ error: "We couldn’t process the request. Your account was not confirmed as deleted. Contact support for help." }); }
    finally { setBusy(false); }
  }
  const errorText = status?.code === "reauth_required" ? "For your security, sign in again and submit the request promptly." : status?.status === "needs_family_review" ? "This account is linked to a family. Support must review the family relationship before deletion can proceed. Contact support while signed in; do not try to delete another member’s account." : status?.status === "needs_billing_cancellation" ? "An active Bloom web billing agreement must be canceled before account deletion can proceed. Contact support to manage that agreement. Store subscriptions are managed separately." : status?.error;
  return <div className="deletion-flow">
    {!configured && <div className="notice-card" role="status"><b>Secure deletion is not connected yet.</b><p>Use Bloom’s in-app Profile → Account deletion control, or contact support. This website has not accepted your credentials.</p></div>}
    {configured && !signedInEmail && <form className="contact-form" onSubmit={signIn}><p>Sign in securely with Bloom. Your password is sent directly to Bloom’s authentication provider and is never sent to this website.</p><label htmlFor="delete-email">Bloom account email</label><input id="delete-email" type="email" autoComplete="username" required value={email} onChange={(event) => setEmail(event.target.value)}/><label htmlFor="delete-password">Password</label><input id="delete-password" type="password" autoComplete="current-password" required value={password} onChange={(event) => setPassword(event.target.value)}/><button className="button button-dark" disabled={busy}>{busy ? "Signing in…" : "Sign in to Bloom"}</button></form>}
    {configured && signedInEmail && <div className="delete-confirm-box"><p>Signed in as <b>{signedInEmail}</b>.</p><label className="consent-option"><input type="checkbox" checked={confirmed} onChange={(event) => setConfirmed(event.target.checked)}/><span>I understand this permanently deletes my personal Bloom account and related records after the request completes. A subscription, if any, is canceled separately.</span></label><button className="button button-danger" disabled={!confirmed || busy} onClick={requestDeletion}>{busy ? "Processing…" : "Request permanent account deletion"}</button><button className="text-link" onClick={async () => { await supabase().auth.signOut(); setSignedInEmail(""); }}>Sign out</button></div>}
    {status && status.status !== "signed_in" && <div className={`notice-card ${status.status === "completed" ? "notice-success" : "notice-warning"}`} role="status"><b>{status.status === "completed" ? "Deletion complete" : "Deletion needs attention"}</b><p>{status.status === "completed" ? "Bloom confirmed that this account deletion completed." : errorText}</p>{status.error && status.status !== "needs_family_review" && status.status !== "needs_billing_cancellation" && <p>{errorText}</p>}</div>}
  </div>;
}
