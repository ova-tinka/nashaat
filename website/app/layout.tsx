import type { Metadata, Viewport } from "next";
import "@fontsource-variable/instrument-sans";
import "@fontsource/instrument-serif/400.css";
import "./globals.css";
import { site, publishedCanonical } from "@/lib/site";
import { SiteNav } from "@/components/site-nav";
import { SiteFooter } from "@/components/site-footer";
import { CookieConsent } from "@/components/cookie-consent";

export const metadata: Metadata = {
  metadataBase: site.origin ? new URL(site.origin) : undefined,
  title: { default: "Bloom — Make screen time worth it", template: "%s — Bloom" },
  description: site.description,
  applicationName: "Bloom",
  alternates: { canonical: publishedCanonical("/") },
  openGraph: { title: "Bloom — Make screen time worth it", description: site.description, siteName: "Bloom", type: "website", url: publishedCanonical("/") },
  twitter: { card: "summary_large_image", title: "Bloom — Make screen time worth it", description: site.description },
  robots: site.origin ? { index: true, follow: true } : { index: false, follow: false },
};

export const viewport: Viewport = { width: "device-width", initialScale: 1, themeColor: "#F7F9FF" };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const jsonLd = { "@context": "https://schema.org", "@type": "Organization", name: "Bloom", description: site.description, url: site.origin || undefined };
  return <html lang="en"><body><a className="skip-link" href="#main-content">Skip to content</a><SiteNav /><main id="main-content">{children}</main><SiteFooter /><CookieConsent /><script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd).replace(/</g, "\\u003c") }} /></body></html>;
}
