import Image from "next/image";
import Link from "next/link";
import { ArrowDown, ArrowRight, ArrowUpRight, Check, ChevronRight, Clock3, HeartHandshake, ShieldCheck, Sparkles } from "lucide-react";
import { BloomMark } from "@/components/brand";
import { PlatformList } from "@/components/platform-list";
import { faqs, products } from "@/lib/site";

const schema = { "@context": "https://schema.org", "@type": "SoftwareApplication", name: "Bloom", applicationCategory: "LifestyleApplication", description: "A digital wellbeing and productivity app connecting exercise, study, reading and tasks with intentional screen time.", operatingSystem: "Android, macOS", url: process.env.NEXT_PUBLIC_BLOOM_SITE_URL || undefined };

export default function HomePage() {
  return <>
    <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(schema).replace(/</g, "\\u003c") }} />
    <section className="hero-section">
      <div className="hero-backdrop" aria-hidden="true"><span className="hero-orbit orbit-one"/><span className="hero-orbit orbit-two"/><span className="hero-sun"/></div>
      <div className="hero-inner page-width">
        <div className="hero-copy"><p className="eyebrow"><span className="eyebrow-dot"/>A little more intention, every day</p>
          <h1>Make screen time<br/><em>worth it.</em></h1>
          <p className="hero-lede">Turn everyday progress into intentional screen time. Move, learn, read and get things done—with room for the things you love online, too.</p>
          <div className="hero-actions"><Link className="button button-dark" href="/download">See platform availability <ArrowRight aria-hidden="true"/></Link><Link className="button button-light" href="/ios">Get iPhone launch updates <ArrowUpRight aria-hidden="true"/></Link></div>
          <p className="hero-note"><span className="tiny-mark"><BloomMark /></span>Bloom is paid. Public downloads are being prepared. <Link href="/download">See what’s available</Link></p>
        </div>
        <div className="hero-visual" aria-label="A real screenshot from the current Bloom app, shown inside a device frame">
          <div className="hero-glow" aria-hidden="true"/><div className="floating-note floating-note-top"><span className="note-icon note-green"><Check/></span><span><b>A little progress</b><small>still counts</small></span></div>
          <div className="phone-shell"><div className="phone-screen"><Image src="/images/bloom-home-current.png" alt="Bloom’s current home screen with activity areas and progress summary. The screenshot is cropped to omit the device status and bottom navigation." fill priority sizes="(max-width: 760px) 60vw, 330px" className="phone-screen-image"/><span className="phone-crop"/></div></div>
          <div className="floating-note floating-note-bottom"><span className="note-icon note-blue"><Sparkles/></span><span><b>Move · Learn · Read · Do</b><small>Four paths, one Bloom</small></span></div>
          <div className="hero-petal petal-one" aria-hidden="true"/><div className="hero-petal petal-two" aria-hidden="true"/>
        </div>
      </div>
      <a className="scroll-cue" href="#why-bloom"><span>Scroll to find your rhythm</span><ArrowDown aria-hidden="true"/></a>
    </section>

    <section className="intro-section section-pad" id="why-bloom"><div className="page-width intro-grid">
      <div className="section-kicker"><span>01 / A different kind of control</span><span className="kicker-line"/></div>
      <div className="intro-content"><p className="eyebrow">Less autopilot. More your choice.</p><h2>Technology can fit<br/>into a <em>fuller life.</em></h2><p className="body-large">The next scroll is always within reach. Bloom gives your attention somewhere meaningful to go first—then helps you choose when it’s time to come back online.</p>
        <div className="problem-pair"><div><span className="problem-number">01</span><h3>Small moments add up</h3><p>It’s easy for the apps you open by habit to take the time you meant to give to something else.</p></div><div><span className="problem-number">02</span><h3>Rules need a reason</h3><p>Blocking alone can feel like a wall. Bloom pairs boundaries with progress you can see.</p></div></div>
      </div>
    </div></section>

    <section className="loop-section section-pad" id="how-it-works"><div className="page-width">
      <div className="section-kicker"><span>02 / The Bloom loop</span><span className="kicker-line"/></div>
      <div className="loop-heading"><div><p className="eyebrow">A rhythm you build yourself</p><h2>Progress earns a pause.<br/><em>Choice keeps it yours.</em></h2></div><p>Do something that matters to you. Earn time you can choose to use. Come back to your day with intention.</p></div>
      <div className="loop-visual" aria-label="Bloom’s four-step approach"><div className="loop-line" aria-hidden="true"/><article className="loop-step"><span className="loop-index">01</span><div className="loop-icon loop-activity"><span className="mini-petals"><BloomMark/></span></div><h3>Do a little good</h3><p>Move, learn, read or finish a task.</p></article><article className="loop-step"><span className="loop-index">02</span><div className="loop-icon loop-credit"><Clock3/></div><h3>Build your balance</h3><p>Earn credits when supported and enabled.</p></article><article className="loop-step"><span className="loop-index">03</span><div className="loop-icon loop-choice"><Sparkles/></div><h3>Choose your moment</h3><p>Use earned time or choose a focus mode.</p></article><article className="loop-step"><span className="loop-index">04</span><div className="loop-icon loop-routine"><HeartHandshake/></div><h3>Find your rhythm</h3><p>Make intentional routines your own.</p></article></div>
      <p className="loop-footnote">Controls depend on your device, permissions and settings. See <Link href="/download">platform details</Link>.</p>
    </div></section>

    <section className="pillars-section section-pad" id="pillars"><div className="page-width">
      <div className="section-kicker"><span>03 / Four paths forward</span><span className="kicker-line"/></div>
      <div className="pillars-heading"><p className="eyebrow">One whole-person ecosystem</p><h2>Make space for what<br/><em>moves you.</em></h2><p>Progress doesn’t look the same every day. Bloom brings four useful parts of life together, so there’s always a next step that feels like yours.</p></div>
      <div className="pillar-feature-list">{products.map((product, i) => <article className={`pillar-feature pillar-${product.color}`} key={product.id} id={`pillar-${product.id}`}>
        <div className={`pillar-art pillar-art-${product.color}`}><Image src={product.image} alt={product.alt} fill sizes="(max-width: 760px) 100vw, 50vw"/><span className="pillar-art-index">0{i + 1}</span></div>
        <div className="pillar-copy"><span className="pillar-label">{product.name} <span aria-hidden="true">/</span> {product.examples}</span><h3>{product.title}</h3><p>{product.text}</p><span className="pillar-caption">Part of your personal Bloom rhythm</span></div>
      </article>)}</div>
    </div></section>

    <section className="control-section section-pad" id="control-modes"><div className="page-width">
      <div className="section-kicker"><span>04 / Set the kind of boundary you need</span><span className="kicker-line"/></div>
      <div className="control-heading"><div><p className="eyebrow">Three ways to take the wheel</p><h2>Your day.<br/><em>Your kind of focus.</em></h2></div><p>Bloom can help you create a little room around distracting apps. Choose a style that supports your plans, with availability shaped by your device.</p></div>
      <div className="mode-list"><article className="mode-row"><span className="mode-no">01</span><div className="mode-visual mode-earned"><div className="mode-clock">12 <small>min</small></div><div className="mode-meter"><span style={{width:"64%"}}/></div><span className="mode-visual-caption">earned by you</span></div><div className="mode-text"><h3>Earned screen time</h3><p>Set selected distractions aside by default. Complete meaningful activities to earn credits you can choose to spend.</p><span>For: a little motivation to start something that matters.</span></div></article>
      <article className="mode-row"><span className="mode-no">02</span><div className="mode-visual mode-focus"><span className="focus-rings"/><span className="focus-center"><BloomMark/></span><span className="focus-label">Just this moment</span></div><div className="mode-text"><h3>Block now</h3><p>Start a voluntary blocking session whenever you want to give a task your full attention.</p><span>For: a focused study session or a quieter evening.</span></div></article>
      <article className="mode-row"><span className="mode-no">03</span><div className="mode-visual mode-schedule"><div className="schedule-sun"/><div className="schedule-track"><span/><span/><span/></div><div className="schedule-days"><b>M</b><b>T</b><b>W</b><b>T</b><b>F</b><b>S</b><b>S</b></div><span className="schedule-caption">A routine that repeats</span></div><div className="mode-text"><h3>Set a schedule</h3><p>Plan recurring windows for distraction controls that match the shape of your week.</p><span>For: a calmer wind-down or homework routine.</span></div></article></div>
      <p className="mode-disclaimer">App blocking requires device permissions and may work differently on each operating system. Saved settings do not always mean a device is actively enforcing them.</p>
    </div></section>

    <section className="family-section section-pad" id="families"><div className="page-width family-grid"><div className="family-visual"><div className="family-image-frame"><Image src="/images/lavender-field.jpg" alt="A quiet field of lavender in soft afternoon light" fill sizes="(max-width: 760px) 100vw, 50vw"/></div><div className="family-quote"><span className="quote-mark">“</span><p>Growing up online<br/>takes practice—for<br/>all of us.</p><span className="quote-caption">Make the conversation part of the routine.</span></div><span className="family-dot" aria-hidden="true"/></div><div className="family-copy"><div className="section-kicker"><span>05 / Grow together</span><span className="kicker-line"/></div><p className="eyebrow">For the whole household</p><h2>More trust.<br/><em>Less tug-of-war.</em></h2><p className="body-large">Bloom works for individuals first, with optional family tools to make healthier digital habits a shared effort—not a secret one.</p><ul className="family-points"><li><ShieldCheck/><span><b>Separate personal spaces</b><small>Each family member keeps their own account and activity.</small></span></li><li><HeartHandshake/><span><b>Support with respect</b><small>Make room for age-appropriate independence and cooperation.</small></span></li><li><Sparkles/><span><b>Progress to talk about</b><small>Build routines around meaningful moments, together.</small></span></li></ul><p className="fine-print">Family and guardian controls vary by app version, device and granted permissions. Bloom does not promote covert monitoring.</p></div></div></section>

    <section className="platform-section section-pad" id="platforms"><div className="page-width"><div className="section-kicker"><span>06 / Find your platform</span><span className="kicker-line"/></div><div className="platform-heading"><div><p className="eyebrow">Made for your everyday devices</p><h2>Bloom is growing<br/><em>across screens.</em></h2></div><Link className="text-link" href="/download">Platform details <ArrowUpRight/></Link></div><PlatformList/></div></section>

    <section className="faq-teaser section-pad"><div className="page-width faq-teaser-grid"><div><p className="eyebrow">A few good questions</p><h2>Clear answers,<br/><em>no fine print.</em></h2><Link className="text-link" href="/faq">Visit the full FAQ <ArrowRight/></Link></div><div className="faq-teaser-list">{faqs.slice(0, 4).map((item) => <details key={item.q}><summary>{item.q}<ChevronRight aria-hidden="true"/></summary><p>{item.a}</p></details>)}</div></div></section>

    <section className="final-cta"><div className="cta-star cta-star-one"/><div className="cta-star cta-star-two"/><div className="page-width cta-inner"><BloomMark/><p className="eyebrow">Make a little room for more</p><h2>Let your day<br/>open <em>up.</em></h2><p>One helpful step can change the shape of the next hour.</p><div className="hero-actions"><Link className="button button-white" href="/download">Explore Bloom <ArrowRight/></Link><Link className="cta-secondary" href="/ios">Get iPhone updates <ArrowUpRight/></Link></div><span className="cta-orbit" aria-hidden="true"/></div></section>
  </>;
}
