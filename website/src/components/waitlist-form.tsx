"use client";

import { FormEvent, useState } from "react";
import Link from "next/link";
import { track } from "@/lib/analytics";

type FormState = { kind: "idle" | "sending" | "success" | "error"; message?: string };

export function WaitlistForm() {
  const [state, setState] = useState<FormState>({ kind: "idle" });
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (state.kind === "sending") return;
    const form = event.currentTarget;
    const values = Object.fromEntries(new FormData(form).entries());
    track("waitlist_submission_attempted");
    if (values.beta_interest === "on") track("waitlist_beta_interest_selected");
    setState({ kind: "sending" });
    try {
      const response = await fetch("/api/waitlist", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ email: values.email, adult: values.adult === "on", beta_interest: values.beta_interest === "on", marketing_consent: values.marketing_consent === "on", website: values.website }) });
      const body = await response.json() as { message?: string; error?: string };
      if (!response.ok) {
        track("waitlist_form_error", { reason: response.status === 429 ? "rate_limited" : response.status === 400 ? "validation" : "service" });
        setState({ kind: "error", message: body.error ?? "We couldn’t submit your request. Please try again in a moment." });
        return;
      }
      track("waitlist_submission_succeeded");
      setState({ kind: "success", message: body.message ?? "If the address can receive Bloom updates, a confirmation message is on its way." });
      form.reset();
    } catch {
      track("waitlist_form_error", { reason: "network" });
      setState({ kind: "error", message: "The connection didn’t go through. Please try again." });
    }
  }

  if (state.kind === "success") return <div className="form-result form-success" role="status"><strong>Check your inbox.</strong><p>{state.message}</p><p>Confirmation is required before Bloom adds an address to launch updates.</p><button className="text-link" type="button" onClick={() => setState({ kind: "idle" })}>Add another address</button></div>;

  return <form className="waitlist-form" onSubmit={submit} noValidate>
    <label className="field-label" htmlFor="waitlist-email">Email address</label>
    <div className="email-submit-row"><input id="waitlist-email" name="email" type="email" autoComplete="email" maxLength={254} required placeholder="you@example.com" aria-describedby="waitlist-email-help waitlist-status"/><button className="button button-dark" type="submit" disabled={state.kind === "sending"}>{state.kind === "sending" ? "Sending…" : "Join the list"}</button></div>
    <p id="waitlist-email-help" className="field-help">For adults and parents or guardians only. You can unsubscribe or ask us to delete your details.</p>
    <label className="consent-option"><input type="checkbox" name="adult" required/><span>I’m 18 or older, or I’m a parent or legal guardian submitting on behalf of my family.</span></label>
    <label className="consent-option consent-optional"><input type="checkbox" name="beta_interest"/><span><b>I’d also like to be considered for the iPhone beta.</b><small>This optional choice is separate from launch updates. Selection is selective, not guaranteed. Complimentary access may be offered to selected testers only during testing, subject to TestFlight availability.</small></span></label>
    <label className="consent-option consent-optional"><input type="checkbox" name="marketing_consent"/><span><b>Email me occasional Bloom product news.</b><small>Optional. The waitlist confirmation and launch update are sent regardless of this choice.</small></span></label>
    <div className="honeypot" aria-hidden="true"><label htmlFor="waitlist-website">Leave this blank</label><input id="waitlist-website" name="website" type="text" tabIndex={-1} autoComplete="off"/></div>
    <p className="consent-note">Joining sends only the iPhone launch confirmation and launch announcement. Read the <Link href="/privacy">privacy draft</Link> to see what is planned; final operator and retention details remain to be confirmed.</p>
    <div id="waitlist-status" className={`form-result ${state.kind === "error" ? "form-error" : ""}`} aria-live="polite">{state.kind === "error" ? state.message : ""}</div>
  </form>;
}
