import type { Metadata } from "next";
import Link from "next/link";
import { FAQList } from "@/components/faq-list";
import { publishedCanonical } from "@/lib/site";

export const metadata: Metadata = { title: "Frequently asked questions", description: "Clear answers about Bloom screen time, platforms, families, subscriptions, privacy and iPhone beta updates.", alternates: { canonical: publishedCanonical("/faq") } };
export default function FAQPage() { return <div className="page-shell faq-page"><section className="page-hero page-width"><p className="eyebrow">Answers, in plain language</p><h1>Good questions.<br/><em>Clear answers.</em></h1><p className="page-lede">A little more context on how Bloom works, what’s available and what’s still in progress.</p></section><section className="faq-page-content page-width"><FAQList/><div className="faq-help"><p>Still have a question?</p><Link className="text-link" href="/support">Get in touch with Bloom support ↗</Link></div></section></div>; }
