// Design first: before any code is generated, the AI draws the app's screens as an interactive design
// prototype (one HTML file). The user reviews it, changes it with AI until it is right, and approves it.
// The approved design is saved as apps/<app>/design.html and the generators build the real app from it.
import AsyncStorage from "@react-native-async-storage/async-storage";
import { askGeminiHtml, AiImage } from "./instantPreview";
import { DESIGN_BRIEF } from "./designBrief";
import { pushFile } from "./github";
import { REPO } from "./config";
import { Lang } from "./langs";
import { forApp } from "./understand";

export type DesignTarget = {
  key: string; // app folder name
  label: string; // shown on the tab
  title: string; // app name for the people using it
  description: string;
  lang: Lang;
  role?: "customer" | "admin";
};

const PLATFORM: Record<Lang, string> = {
  html: "a modern mobile web app (it will ship as a WebView app)",
  react: "a React single-page mobile app (one self-contained index.html using React 18 and hooks via CDN, no build step), styled to look and feel like a native mobile app inside a WebView",
  flutter: "a Flutter Material 3 app: use Material 3 shapes, components, elevation and motion so the design maps 1:1 to Flutter widgets",
  python: "a Python Flet (Material 3) app: use Material 3 components only, so every element maps to a Flet control",
  kotlin: "a native Android app in Kotlin with Jetpack Compose Material 3: use Material 3 components, shapes and motion so every element maps 1:1 to a Compose composable",
};

const DESIGNER = `You are a world-class mobile product designer and senior front-end engineer.
This is the DESIGN STAGE only: focus entirely on the user interface, visual design and user experience.
No real backend: use realistic sample data inside the page.

Deliver ONE self-contained HTML file (inline CSS and JS, no external files, fonts or images) that is a
high-fidelity, clickable prototype of the WHOLE app:
- Every main screen of the app, each as its own view, connected with working navigation (bottom bar, tabs,
  buttons, back arrows, sheets and dialogs open and close).
- A slim, elegant "screens" switcher fixed at the very top (element with id="apkfact-screens"): a horizontally
  scrollable row of small pills with each screen's name, so the reviewer can jump to any screen. Keep it
  visually separate from the app (dark translucent bar). Everything else is the app itself.
- Show key states too: at least one empty state and one loading skeleton (reachable from the switcher).
- Phone-first layout (360-430px wide, full height), right-to-left with Arabic text when the description is
  in Arabic.

${DESIGN_BRIEF}
Reply with ONLY the file inside a single \`\`\`html code block.`;

function platformLine(t: DesignTarget) {
  return `Design it as ${PLATFORM[t.lang]}.`;
}

function roleLine(t: DesignTarget) {
  if (t.role === "admin")
    return "This is the ADMIN / management app of the business: dashboard with KPI cards and charts, managing every record, statuses, reports, customers list, notifications inbox, settings.";
  if (t.role === "customer")
    return "This is the CUSTOMER app of the business: sign in with an email code, browse, create and follow their own records, notifications inbox, profile.";
  return "";
}

function hash(s: string) {
  let h = 5381;
  for (let i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) | 0;
  return (h >>> 0).toString(36);
}

// Design directions to nudge each app towards a different look, so two apps never come out the same.
const SCHOOLS = [
  "Minimal / Swiss (airy, strong type hierarchy, few colors, hairlines)",
  "Editorial / Magazine (big display headings, serif accents, asymmetric layouts)",
  "Soft & rounded friendly (large radii, pastel tints, playful rounded icons)",
  "Neo-brutalist bold (high contrast, solid borders, blocky flat colors, chunky buttons)",
  "Glass & depth (translucent layered surfaces, blur, soft glows, gradients)",
  "Premium dark luxe (dark surfaces, gold/metallic accents, elegant type, generous spacing)",
  "Vibrant gradient (energetic gradient hero, bold accent, geometric shapes)",
  "Expressive tonal / Material-you (dynamic tonal palette, large rounded components)",
];

// A stable-but-varied design direction for this specific app (same app -> same seed, different apps -> different).
function seedSchool(t: DesignTarget) {
  const n = parseInt(hash(`${t.key}|${t.description}`), 36) || 0;
  return SCHOOLS[n % SCHOOLS.length];
}

// Drafts survive closing APK Fact; they belong to one app name + language + description.
const draftKey = (t: DesignTarget) => `design-draft:${t.key}:${hash(`${t.lang}|${t.role ?? ""}|${t.description}`)}`;

export async function loadDraft(t: DesignTarget): Promise<string[] | null> {
  try {
    const v = await AsyncStorage.getItem(draftKey(t));
    return v ? (JSON.parse(v) as string[]) : null;
  } catch {
    return null;
  }
}

export async function saveDraft(t: DesignTarget, history: string[]) {
  try {
    await AsyncStorage.setItem(draftKey(t), JSON.stringify(history.slice(-6)));
  } catch {}
}

export async function clearDraft(t: DesignTarget) {
  try {
    await AsyncStorage.removeItem(draftKey(t));
  } catch {}
}

/** First design of an app. `brandFrom` is another approved design to share colors, fonts and style with.
 *  `images` are reference pictures the owner attached to their description (sent to the AI as a visual guide). */
export async function designApp(
  t: DesignTarget,
  onStatus: (s: string) => void,
  brandFrom?: string,
  images: AiImage[] = [],
  onPartial?: (html: string) => void
) {
  let prompt =
    `App name: ${t.title}\n${platformLine(t)}\n${roleLine(t)}\n\nWhat the app is and does:\n${forApp(t.description, t.role)}\n` +
    (t.role
      ? `\nDesign ONLY the ${t.role === "admin" ? "ADMIN" : "CUSTOMER"} app: its own items and the shared ones («الاثنين»). ` +
        `The other app of the pair is designed separately; do not put its screens here.\n`
      : "");
  if (brandFrom) {
    // The second app of a pair must share the first app's brand, so no new direction here.
    prompt +=
      "\nThis app belongs to the same business as the design below. Use the SAME brand: palette, fonts, " +
      "corner radius, icon style and component look, so the two apps feel like one product:\n```html\n" +
      brandFrom.slice(0, 40000) +
      "\n```\n";
  } else {
    // Push this app towards its own identity, nudged to a different design direction than other apps.
    prompt +=
      `\nMake THIS app visually unique to «${t.title}» and its audience: choose a design direction and a signature ` +
      "look, and commit to it on every screen (palette, typography personality, shape language, and one signature " +
      "element). Do NOT produce a generic template — another app must look clearly different. Unless the business " +
      `clearly calls for another style, lean towards a ${seedSchool(t)} direction and adapt it to fit this business.\n`;
  }
  if (images.length) {
    prompt +=
      "\nThe owner attached the image(s) above as a VISUAL REFERENCE for how they want the app to look — follow its " +
      "style, layout, colors, components and overall feel as closely as it fits this app and its screens.\n";
  }
  return askGeminiHtml(DESIGNER, prompt, onStatus, "يصمّم الواجهات", brandFrom ? 0.7 : 0.85, images, onPartial);
}

/** Applies a requested change to an existing design and returns the full new design. */
export async function reviseDesign(t: DesignTarget, html: string, change: string, onStatus: (s: string) => void) {
  const prompt =
    `App name: ${t.title}\n${platformLine(t)}\n${roleLine(t)}\n\nCurrent design:\n\`\`\`html\n${html}\n\`\`\`\n\n` +
    `Change requested by the owner (apply it fully and precisely; keep everything else as it is unless the change ` +
    `needs it; keep the screens switcher):\n${change}\n`;
  return askGeminiHtml(DESIGNER, prompt, onStatus, "يعدّل التصميم", 0.5);
}

/** Saves the approved design next to the app so the generators build from it. */
export async function saveApprovedDesign(app: string, html: string) {
  await pushFile(REPO, `apps/${app}/design.html`, html.trim() + "\n", `Approved design: ${app}`);
}
