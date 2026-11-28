import type { Metadata } from "next";
import Link from "next/link";
import { ArrowRight, ShieldCheck, Sparkles } from "lucide-react";
import { WaitlistForm } from "@/components/waitlist-form";
import { IOSPageView } from "@/components/ios-page-view";

export const metadata: Metadata = { title: "iPhone launch updates", description: "Get notified when Bloom launches on iPhone. Beta consideration is a separate, optional opt-in." };

export default function IOSPage() {
  return <><IOSPageView/><div className="page-shell ios-page"><section className="ios-hero page-width"><div className="ios-hero-copy"><p className="eyebrow"><span className="eyebrow-dot"/>An iPhone chapter is growing</p><h1>Bloom is on<br/>its <em>way to iPhone.</em></h1><p className="page-lede">Get one helpful note when Bloom is ready for iPhone. Beta consideration is a different choice—opt in only if it interests you.</p><div className="availability-tag"><span/>Not publicly available yet <span className="availability-divider">·</span> No release date announced</div></div><div className="ios-illustration" aria-hidden="true"><div className="ios-orbit ios-orbit-a"/><div className="ios-orbit ios-orbit-b"/><div className="ios-phone"><div className="ios-dynamic-island"/><div className="ios-logo"><span/><span/><span/><span/></div><b>Bloom</b><small>Make room to grow.</small><div className="ios-app-lines"><i/><i/><i/></div></div><span className="ios-spark ios-spark-a">✳</span><span className="ios-spark ios-spark-b">✳</span></div></section>
    <section className="waitlist-section page-width" id="join"><div className="waitlist-panel"><div className="waitlist-panel-copy"><p className="eyebrow">Keep me in the loop</p><h2>A note when<br/><em>Bloom arrives.</em></h2><p>We’ll confirm your email first. No account is created, and children should not register directly.</p><div className="waitlist-privacy"><ShieldCheck/><span><b>Your email stays private</b><small>Never shown publicly or included in analytics.</small></span></div></div><div className="waitlist-panel-form"><WaitlistForm/></div></div></section>
    <section className="beta-explainer page-width"><div><Sparkles/><h2>Curious about the beta?</h2></div><p>Check the separate beta box above if you’d like to be considered. Invitations may be selective, and registration does not guarantee a spot. Selected testers may receive complimentary access while the beta is running. It doesn’t promise a permanent free plan.</p><Link className="text-link" href="/faq">Learn how beta invitations work <ArrowRight/></Link></section>
    <p className="ios-backlink page-width">Looking for a different platform? <Link href="/download">See Bloom release availability</Link>.</p></div></>;
}
