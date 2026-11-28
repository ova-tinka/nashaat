import Link from "next/link";

export function BloomMark({ className = "" }: { className?: string }) {
  return <svg className={`bloom-mark ${className}`} viewBox="0 0 44 44" role="img" aria-label="Bloom mark">
    <path d="M21.5 5.1c-7.2 0-11.8 5.9-11.8 13.2 7.3 0 13.2-4.6 13.2-11.8V5.1h-1.4Z" fill="#7A6BEA" />
    <path d="M38.9 21.5c0-7.2-5.9-11.8-13.2-11.8 0 7.3 4.6 13.2 11.8 13.2h1.4v-1.4Z" fill="#56B99A" />
    <path d="M22.5 38.9c7.2 0 11.8-5.9 11.8-13.2-7.3 0-13.2 4.6-13.2 11.8v1.4h1.4Z" fill="#F17F9D" />
    <path d="M5.1 22.5c0 7.2 5.9 11.8 13.2 11.8 0-7.3-4.6-13.2-11.8-13.2H5.1v1.4Z" fill="#62A7F6" />
  </svg>;
}

export function Wordmark({ inverse = false }: { inverse?: boolean }) {
  return <Link className={`wordmark${inverse ? " wordmark-inverse" : ""}`} href="/" aria-label="Bloom home">
    <BloomMark /><span>bloom</span>
  </Link>;
}
