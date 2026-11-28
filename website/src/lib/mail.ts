import "server-only";
import nodemailer from "nodemailer";

export class MailUnavailableError extends Error {}

function mailSettings() {
  const host = process.env.SMTP_HOST;
  const port = Number(process.env.SMTP_PORT ?? "587");
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASSWORD;
  const from = process.env.SMTP_FROM;
  if (!host || !Number.isInteger(port) || port < 1 || port > 65535 || !user || !pass || !from || !process.env.SUPPORT_INBOX) {
    throw new MailUnavailableError("Email delivery is not configured");
  }
  return { host, port, user, pass, from, inbox: process.env.SUPPORT_INBOX };
}

export function emailReady() {
  try { mailSettings(); return true; } catch { return false; }
}

export function escapeHtml(text: string) {
  return text.replace(/[&<>"']/gu, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[char] ?? char);
}

function transporter() {
  const settings = mailSettings();
  return { settings, transport: nodemailer.createTransport({ host: settings.host, port: settings.port, secure: settings.port === 465, requireTLS: settings.port !== 465, auth: { user: settings.user, pass: settings.pass } }) };
}

export async function sendWaitlistConfirmation(email: string, confirmationUrl: string, managementUrl: string) {
  const { settings, transport } = transporter();
  await transport.sendMail({ from: settings.from, to: email, subject: "Confirm your Bloom iPhone updates", text: `Confirm your request for iPhone launch updates: ${confirmationUrl}\n\nYou can also review or delete your waitlist details here: ${managementUrl}\n\nYou are receiving this because an adult submitted the Bloom waitlist form.`, html: `<p>Please confirm your request for Bloom iPhone launch updates.</p><p><a href="${escapeHtml(confirmationUrl)}">Confirm launch updates</a></p><p>You can review or delete your waitlist details at any time: <a href="${escapeHtml(managementUrl)}">manage your preferences</a>.</p><p>You are receiving this because an adult submitted the Bloom waitlist form.</p>` });
}

export async function sendManagementLink(email: string, managementUrl: string) {
  const { settings, transport } = transporter();
  await transport.sendMail({ from: settings.from, to: email, subject: "Manage your Bloom launch updates", text: `Use this secure link to change your Bloom beta or product news preferences, unsubscribe, or delete your waitlist details: ${managementUrl}\n\nThe link expires in 30 minutes.`, html: `<p>Use this secure link to change your Bloom beta or product news preferences, unsubscribe, or delete your waitlist details:</p><p><a href="${escapeHtml(managementUrl)}">Manage Bloom updates</a></p><p>The link expires in 30 minutes.</p>` });
}

export async function sendSupportMessage(input: { name: string; email: string; topic: string; message: string }) {
  const { settings, transport } = transporter();
  await transport.sendMail({ from: settings.from, to: settings.inbox, replyTo: input.email, subject: `[Bloom support] ${input.topic}`, text: `Name: ${input.name}\nReply address: ${input.email}\nTopic: ${input.topic}\n\n${input.message}` });
}
