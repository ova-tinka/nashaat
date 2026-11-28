import type { Metadata } from "next";
import { ContactForm } from "@/components/contact-form";
import { publishedCanonical } from "@/lib/site";

export const metadata: Metadata = { title: "Contact Bloom", description: "Contact the Bloom team for support, privacy requests and questions.", alternates: { canonical: publishedCanonical("/contact") } };
export default function ContactPage() { return <div className="page-shell contact-page"><section className="page-hero page-width"><p className="eyebrow">Here when you need us</p><h1>Talk to<br/><em>Bloom.</em></h1><p className="page-lede">Tell us how we can help. This form won’t ask for passwords or payment information.</p></section><section className="page-width contact-content"><div className="contact-intro"><h2>We read every note.</h2><p>Share a concise description and the email associated with your Bloom account if relevant. Please don’t include information about a child that isn’t needed to help.</p><p>Account deletion requests are available through the <a href="/delete-account">secure deletion pathway</a>.</p></div><ContactForm/></section></div>; }
