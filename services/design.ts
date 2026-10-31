// Design first: before any code is generated, the AI draws the app's screens as an interactive design
// prototype (one HTML file). The user reviews it, changes it with AI until it is right, and approves it.
// The approved design is saved as apps/<app>/design.html and the generators build the real app from it.
import AsyncStorage from "@react-native-async-storage/async-storage";
import { askGeminiHtml } from "./instantPreview";
import { DESIGN_BRIEF } from "./designBrief";
import { pushFile } from "./github";
import { REPO } from "./config";
import { Lang } from "./langs";

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
  flutter: "a Flutter Material 3 app: use Material 3 shapes, components, elevation and motion so the design maps 1:1 to Flutter widgets",
  python: "a Python Flet (Material 3) app: use Material 3 components only, so every element maps to a Flet control",
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

/** First design of an app. `brandFrom` is another approved design to share colors, fonts and style with. */
export async function designApp(t: DesignTarget, onStatus: (s: string) => void, brandFrom?: string) {
  let prompt =
    `App name: ${t.title}\n${platformLine(t)}\n${roleLine(t)}\n\nWhat the app is and does:\n${t.description}\n`;
  if (brandFrom) {
    prompt +=
      "\nThis app belongs to the same business as the design below. Use the SAME brand: palette, fonts, " +
      "corner radius, icon style and component look, so the two apps feel like one product:\n```html\n" +
      brandFrom.slice(0, 40000) +
      "\n```\n";
  }
  return askGeminiHtml(DESIGNER, prompt, onStatus, "يصمّم الواجهات", 0.7);
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
