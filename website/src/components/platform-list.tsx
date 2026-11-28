import Link from "next/link";
import { ArrowUpRight, Apple, Smartphone, Monitor, Laptop } from "lucide-react";
import { platforms } from "@/lib/site";

const icons = { Android: Smartphone, macOS: Laptop, iPhone: Apple, Windows: Monitor };
export function PlatformList({ compact = false }: { compact?: boolean }) {
  return <div className={`platform-list${compact ? " platform-list-compact" : ""}`}>
    {platforms.map((platform) => {
      const Icon = icons[platform.name];
      return <article className={`platform-item platform-${platform.id}`} key={platform.id}>
        <div className="platform-top"><span className="platform-icon"><Icon aria-hidden="true" /></span><span className={`platform-status status-${platform.state}`}>{platform.label}</span></div>
        <h3>{platform.name}</h3><p>{platform.detail}</p>
        {platform.id === "ios" ? <Link className="text-link" href="/ios">Get launch updates <ArrowUpRight aria-hidden="true" /></Link> : <span className="platform-note">No download available</span>}
      </article>;
    })}
  </div>;
}
