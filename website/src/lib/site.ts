export const site = {
  name: "Bloom",
  description: "Build a more intentional relationship with screen time. Move, learn, read and get things done with Bloom.",
  origin: process.env.NEXT_PUBLIC_BLOOM_SITE_URL?.replace(/\/$/, "") ?? "",
};

export const publishedCanonical = (path: string) => site.origin ? `${site.origin}${path}` : undefined;

export const products = [
  { id: "exercise", name: "Move", title: "Make room for movement.", text: "Plan exercise, follow a session or build a routine around the movement that fits your day.", image: "/images/pillars/exercise.jpg", alt: "A bright, quiet space set up for a movement session", color: "mint", examples: "Workouts · Plans · Progress" },
  { id: "study", name: "Learn", title: "Give focus a place to land.", text: "Organize learning into courses, lessons and practice you can return to with purpose.", image: "/images/pillars/study.jpg", alt: "A calm desk arranged for a study session", color: "blue", examples: "Courses · Lessons · Revision" },
  { id: "read", name: "Read", title: "Make time for the next page.", text: "Keep a personal reading list and make steady progress through focused reading sessions.", image: "/images/pillars/read.jpg", alt: "An open book and a warm drink by a window", color: "lilac", examples: "Reading lists · Discovery · Progress" },
  { id: "tasks", name: "Do", title: "Turn good intentions into done.", text: "Gather everyday responsibilities, make a plan and give meaningful tasks a place in the day.", image: "/images/pillars/tasks.jpg", alt: "A paper journal and pen ready for planning", color: "rose", examples: "Lists · Planning · Completion" },
] as const;

export const faqs = [
  { q: "How does Bloom connect activities and screen time?", a: "Bloom brings exercise, study, reading and tasks into one place. When earned screen time is available on your device, you can connect selected activities with screen time credits. Your device’s permissions and platform support affect how distraction controls work." },
  { q: "Do I have to earn every minute of screen time?", a: "No. Bloom has three approaches: earn screen time through activities, start a voluntary blocking session when you want focus, or set a recurring schedule where supported. Choose the approach that suits your routine." },
  { q: "Which platforms can I download today?", a: "Bloom does not currently have a verified public production download link. Android and macOS releases are being prepared for a public launch. iPhone visitors can join launch updates. Windows is planned, with no release date announced." },
  { q: "How much does Bloom cost? Is there a free trial?", a: "Bloom is a paid product. Public pricing and subscription availability are not yet published, and there is no general free tier or public free trial. Selected beta testers may be offered complimentary access for testing, which does not promise a permanent free subscription." },
  { q: "Can I use Bloom on my own?", a: "Yes. Personal use is designed to work without family or organization supervision. Family features are optional." },
  { q: "How does the family experience work?", a: "Bloom supports separate family accounts and wallets with optional parent-child supervision. Supervision is intended to support cooperation and age-appropriate independence. Device and guardian features depend on the available build and permissions." },
  { q: "When will Bloom be available on iPhone?", a: "There is no public release date yet. Join the iPhone list to receive launch updates. Beta consideration is a separate, optional choice and is not guaranteed." },
  { q: "What does beta participation mean?", a: "You can separately opt in to be considered for a selective iPhone beta. Registration does not guarantee an invitation. Selected testers may receive complimentary access during testing, subject to TestFlight availability and Apple’s requirements." },
  { q: "How do I manage my account or request deletion?", a: "Use the account deletion page to sign in and submit a request securely. Your subscription, if any, must be canceled separately with the store or billing provider that manages it." },
  { q: "Does Bloom track everything I do on my device?", a: "Bloom's app controls depend on operating-system permissions. The public site does not ask for information about children. Optional website analytics stay off until you consent." },
] as const;

export const platforms = [
  { id: "android", name: "Android", state: "preparing", label: "Public release not verified", detail: "A public store listing has not been verified yet." },
  { id: "macos", name: "macOS", state: "preparing", label: "Public release not verified", detail: "The current desktop build is not ready for public download." },
  { id: "ios", name: "iPhone", state: "waitlist", label: "Join launch updates", detail: "The iPhone app is not publicly available yet." },
  { id: "windows", name: "Windows", state: "planned", label: "Planned", detail: "In development planning. No release date announced." },
] as const;
