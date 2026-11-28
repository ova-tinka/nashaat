"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Menu, X } from "lucide-react";
import { Wordmark } from "@/components/brand";

const links = [
  ["The Bloom loop", "/#how-it-works"],
  ["Explore Bloom", "/#pillars"],
  ["For families", "/#families"],
  ["FAQ", "/faq"],
] as const;

export function SiteNav() {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();
  return <header className="site-header"><nav className="nav-wrap" aria-label="Main navigation">
    <Wordmark />
    <div className={`nav-links${open ? " nav-links-open" : ""}`}>
      {links.map(([label, href]) => <Link key={href} href={href} onClick={() => setOpen(false)} aria-current={pathname === href ? "page" : undefined}>{label}</Link>)}
      <Link className="nav-download" href="/download" onClick={() => setOpen(false)}>Find your Bloom <span aria-hidden="true">↗</span></Link>
    </div>
    <button className="nav-toggle" type="button" aria-label={open ? "Close navigation" : "Open navigation"} aria-expanded={open} onClick={() => setOpen(!open)}>{open ? <X /> : <Menu />}</button>
  </nav></header>;
}
