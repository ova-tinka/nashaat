import Link from "next/link";
import { Wordmark } from "@/components/brand";

export function SiteFooter() {
  return <footer className="site-footer">
    <div className="footer-main"><div className="footer-brand"><Wordmark /><p>Make space for the things<br />that move you forward.</p></div>
      <div className="footer-column"><h2>Explore</h2><Link href="/#pillars">Four ways to grow</Link><Link href="/#how-it-works">How it works</Link><Link href="/#families">For families</Link><Link href="/download">Platforms</Link></div>
      <div className="footer-column"><h2>Help</h2><Link href="/faq">Frequently asked questions</Link><Link href="/support">Support</Link><Link href="/contact">Contact Bloom</Link><Link href="/delete-account">Delete an account</Link></div>
      <div className="footer-column"><h2>Information</h2><Link href="/privacy">Privacy <span className="draft-label">draft</span></Link><Link href="/terms">Terms <span className="draft-label">draft</span></Link><Link href="/cookies">Cookies</Link><Link href="/ios">iPhone updates</Link></div>
    </div><div className="footer-bottom"><span>© {new Date().getFullYear()} Bloom</span><span>Built for more intentional days.</span></div>
  </footer>;
}
