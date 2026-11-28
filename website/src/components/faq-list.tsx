"use client";

import { ChevronRight } from "lucide-react";
import { faqs } from "@/lib/site";
import { track } from "@/lib/analytics";

export function FAQList() {
  return <div className="faq-list">{faqs.map((item, index) => <details key={item.q} onToggle={(event) => { if ((event.currentTarget as HTMLDetailsElement).open) track("faq_opened", { item: String(index + 1) }); }}>
    <summary><span>{item.q}</span><ChevronRight aria-hidden="true"/></summary><p>{item.a}</p>
  </details>)}</div>;
}
