import type { Metadata } from "next";
import { Suspense } from "react";
import { WaitlistManagement } from "@/components/waitlist-management";

export const metadata: Metadata = { title: "Manage waitlist preferences", robots: { index: false, follow: false }, referrer: "no-referrer" };
export default function ManageWaitlistPage() { return <div className="page-shell"><Suspense fallback={<div className="centered-message page-width">Loading preferences…</div>}><WaitlistManagement/></Suspense></div>; }
