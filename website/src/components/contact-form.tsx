"use client";

import { FormEvent, useState } from "react";

export function ContactForm() {
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    setBusy(true);
    const values = Object.fromEntries(new FormData(event.currentTarget).entries());
    const response = await fetch("/api/contact", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(values) }).catch(() => null);
    const body = response ? await response.json().catch(() => ({})) : {};
    setStatus(response?.ok ? body.message : body.error ?? "The message could not be sent. Please try again later.");
    if (response?.ok) event.currentTarget.reset();
    setBusy(false);
  }
  return <form className="contact-form" onSubmit={submit}>
    <label htmlFor="contact-name">Your name</label><input id="contact-name" name="name" autoComplete="name" maxLength={100} required/>
    <label htmlFor="contact-email">Email address</label><input id="contact-email" name="email" type="email" autoComplete="email" maxLength={254} required/>
    <label htmlFor="contact-topic">What do you need help with?</label><select id="contact-topic" name="topic" defaultValue="general"><option value="general">A general question</option><option value="account">My account</option><option value="deletion">Account deletion</option><option value="privacy">Privacy or data</option><option value="family">Family features</option><option value="accessibility">Accessibility</option><option value="other">Something else</option></select>
    <label htmlFor="contact-message">Message</label><textarea id="contact-message" name="message" rows={5} maxLength={3000} required/>
    <div className="honeypot" aria-hidden="true"><label htmlFor="contact-company">Leave blank</label><input id="contact-company" name="company" tabIndex={-1} autoComplete="off"/></div>
    <button className="button button-dark" type="submit" disabled={busy}>{busy ? "Sending…" : "Send to support"}</button><p className="form-result" aria-live="polite">{status}</p>
    <p className="field-help">Please don’t include passwords or sensitive information about a child in your message.</p>
  </form>;
}
