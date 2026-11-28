import type { Metadata } from "next";
import Link from "next/link";
import { ArrowRight, CheckCircle2, CircleHelp } from "lucide-react";
import { PlatformList } from "@/components/platform-list";
import { publishedCanonical } from "@/lib/site";

export const metadata: Metadata = { title: "Download Bloom", description: "See Bloom’s verified release availability for Android, macOS, iPhone and Windows.", alternates: { canonical: publishedCanonical("/download") } };

export default function DownloadPage() {
  return <div className="page-shell download-page"><section className="page-hero page-width"><p className="eyebrow"><span className="eyebrow-dot"/>Bloom, on your platform</p><h1>Find your<br/><em>Bloom.</em></h1><p className="page-lede">We only link verified public releases. At the moment, Bloom is preparing its first public downloads.</p><div className="release-banner"><CircleHelp aria-hidden="true"/><span><b>No verified public app downloads are available yet.</b><small>We’ll add a store or installer link here after each release passes its checks.</small></span></div></section>
    <section className="page-width download-platforms"><div className="section-heading-inline"><div><p className="eyebrow">Release status</p><h2>Choose your device</h2></div><span className="verified-stamp"><CheckCircle2/>Links are checked before publishing</span></div><PlatformList/></section>
    <section className="release-details page-width"><div><p className="eyebrow">What happens next</p><h2>Ready means<br/><em>safe to install.</em></h2></div><div className="release-details-copy"><p>Before a download appears here, Bloom will verify the store listing or installer, signing, supported operating systems, and release notes. The current macOS app build is not notarized for public distribution, and Android’s public store listing has not been verified.</p><p>We’ll publish version, minimum OS, architecture, file size and integrity details with each direct installer when available.</p><Link className="text-link" href="/ios">iPhone visitors can join launch updates <ArrowRight/></Link></div></section>
    <section className="platform-help page-width"><span>Need a hand?</span><p>Visit <Link href="/support">support</Link> or <Link href="/faq">read the answers</Link> before installing any Bloom app.</p></section></div>;
}
