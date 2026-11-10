// "Did I understand you?" — before any design or code, the AI turns the owner's idea (even one line) into a
// clear list of requirements and asks short questions about what is unclear. The owner edits the list and
// answers; the approved list is added to the description, so the design, the code and the request check
// after generation all follow it item by item.
import { askGemini } from "./instantPreview";
import { Lang } from "./langs";
import PERM_RULES from "./permissions.json";

export type Question = { q: string; options: string[] };
export type Spec = {
  summary: string;
  screens: string[];
  features: string[];
  data: string[];
  texts: string[];
  permissions: string[]; // keys from permissions.json
  questions: Question[];
};
export type ListKey = "screens" | "features" | "data" | "texts";

export const LIST_TITLES: Record<ListKey, string> = {
  screens: "الشاشات",
  features: "الميزات والوظائف",
  data: "البيانات اللي التطبيق بيحفظها",
  texts: "الأسماء والنصوص والأرقام والألوان",
};

const PERM_KEYS = PERM_RULES.keys.map((k) => k.key);
const permLabel = (k: string) => PERM_RULES.keys.find((p) => p.key === k)?.label ?? k;

const LANG_NAME: Record<Lang, string> = {
  html: "an HTML mobile web app",
  react: "a React single-page mobile web app",
  flutter: "a Flutter app",
  python: "a Python (Flet) app",
  kotlin: "a native Android Kotlin (Jetpack Compose) app",
};

const SYSTEM = `You are a senior product manager. The owner describes a mobile app idea in their own words, often
briefly. Your job is to understand EXACTLY what they have in mind, not to invent a different app.
- Keep their idea, domain, names, texts, numbers, prices, colors and language exactly as they wrote them.
- Turn it into a clear, complete list of requirements a developer can build and check one by one.
- Where the idea is short, fill the gaps with what such an app normally needs, but stay inside their idea.
- Sign-in is the owner's decision: list sign-in, accounts, passwords or email login ONLY when their words ask for
  it, and never ask about it (they write it in the description when they want it).
- Ask ONLY about things that really change the app and that you cannot reasonably decide yourself
  (0 to 5 questions). Each question gets 2 to 4 short ready answers (the most likely first).
- Write everything in the owner's language (Arabic when they wrote Arabic, in the same dialect style), short
  and simple, no technical words.
Reply with JSON only, no markdown:
{"summary": "one or two sentences: what the app is and who uses it",
 "screens": ["each screen and what is on it"],
 "features": ["each feature or behavior, one short checkable sentence"],
 "data": ["what the app saves, with its fields"],
 "texts": ["exact names, texts, prices, numbers or colors the owner mentioned"],
 "permissions": ["only from: ${PERM_KEYS.join(", ")} — only what the app really needs"],
 "questions": [{"q": "question", "options": ["answer 1", "answer 2"]}]}`;

function parseSpec(text: string): Spec {
  const s = String(text);
  const a = s.indexOf("{");
  const b = s.lastIndexOf("}");
  if (a < 0 || b < a) throw new Error("الرد ما فيه قائمة المتطلبات");
  const o = JSON.parse(s.slice(a, b + 1));
  const list = (v: any) => (Array.isArray(v) ? v.map((x) => String(x).trim()).filter(Boolean).slice(0, 40) : []);
  const spec: Spec = {
    summary: String(o.summary ?? "").trim(),
    screens: list(o.screens),
    features: list(o.features),
    data: list(o.data),
    texts: list(o.texts),
    permissions: list(o.permissions)
      .map((x) => x.toUpperCase())
      .filter((x, i, arr) => PERM_KEYS.includes(x) && arr.indexOf(x) === i),
    questions: (Array.isArray(o.questions) ? o.questions : [])
      .map((q: any) => ({ q: String(q?.q ?? "").trim(), options: list(q?.options).slice(0, 4) }))
      .filter((q: Question) => q.q)
      .slice(0, 5),
  };
  if (!spec.summary && !spec.features.length && !spec.screens.length) throw new Error("القائمة فاضية");
  return spec;
}

/** First understanding of the idea. */
export type IdeaTarget = { title: string; description: string; lang: Lang; pair?: boolean };

const PAIR_LINE =
  "This is a SYSTEM of two connected apps sharing one online database: a CUSTOMER app (the people who use the " +
  "service) and an ADMIN app (the business that manages everything). Start every screen, feature and data item " +
  "with «الزبون: », «الإدارة: » or «الاثنين: » to say which app it belongs to, and cover both apps fully.\n";

function intro(t: IdeaTarget) {
  return `App name: ${t.title}\nIt will be built as ${LANG_NAME[t.lang]}.\n${t.pair ? PAIR_LINE : ""}\n`;
}

export async function understandIdea(
  t: IdeaTarget,
  onStatus: (s: string) => void
): Promise<Spec> {
  const prompt =
    intro(t) +
    `THE OWNER'S IDEA (their exact words, the highest priority):\n${t.description}\n`;
  return askGemini(SYSTEM, prompt, onStatus, "يفهم فكرتك", 0.3, parseSpec);
}

/** Applies the owner's answers and corrections to the list. */
export async function refineSpec(
  t: IdeaTarget,
  spec: Spec,
  answers: { q: string; a: string }[],
  notes: string,
  onStatus: (s: string) => void
): Promise<Spec> {
  const current = { ...spec, questions: undefined };
  let prompt =
    intro(t) +
    `THE OWNER'S IDEA (their exact words):\n${t.description}\n\n` +
    `YOUR CURRENT LIST (the owner already removed what they don't want; do not add those back):\n` +
    JSON.stringify(current, null, 1) +
    "\n";
  if (answers.length)
    prompt += `\nTHE OWNER'S ANSWERS (apply each one to the list):\n` + answers.map((x) => `- ${x.q} → ${x.a}`).join("\n") + "\n";
  if (notes.trim()) prompt += `\nTHE OWNER'S CORRECTIONS AND ADDITIONS (apply exactly):\n${notes.trim()}\n`;
  prompt +=
    "\nReturn the full updated list in the same JSON format. Ask new questions only if something important " +
    "is still unclear (usually none). Do not ask again what was answered.";
  return askGemini(SYSTEM, prompt, onStatus, "يحدّث الفهم", 0.3, parseSpec);
}

/**
 * The approved list as text, added after the owner's description. scripts/perms.py reads the
 * ANDROID_PERMISSIONS line; the generators and the request check read the whole block.
 */
export function specText(spec: Spec) {
  const out = ["", "=== المواصفات اللي وافق عليها صاحب التطبيق (نفّذها كلها بند بند، ولا تضيف تطبيق مختلف) ==="];
  if (spec.summary) out.push(`الفكرة: ${spec.summary}`);
  (Object.keys(LIST_TITLES) as ListKey[]).forEach((k) => {
    if (spec[k].length) out.push(`${LIST_TITLES[k]}:`, ...spec[k].map((x) => `- ${x}`));
  });
  if (spec.permissions.length) {
    out.push(`الصلاحيات: ${spec.permissions.map(permLabel).join("، ")}`);
    out.push(`ANDROID_PERMISSIONS: ${spec.permissions.join(", ")}`);
  }
  return out.join("\n");
}

/**
 * What one app's designer should read: the description and approved list without the lines meant for the builds
 * (ANDROID_PERMISSIONS, LOGIN, the permissions summary), and for an app of a pair only its own items
 * («الزبون:» / «الإدارة:») plus the shared ones («الاثنين:»). Same rules as forApp() in scripts/pair.py.
 */
export function forApp(text: string, role?: "customer" | "admin") {
  const other = role === "customer" ? "الإدارة" : role === "admin" ? "الزبون" : "";
  return String(text)
    .split("\n")
    .filter((line) => !/^\s*(ANDROID_PERMISSIONS|LOGIN):/.test(line) && !/^\s*الصلاحيات:/.test(line))
    .filter((line) => !other || !new RegExp(`^\\s*-\\s*«?\\s*${other}\\s*(:\\s*»|»\\s*:|:)`).test(line))
    .join("\n")
    .trim();
}

export { permLabel, PERM_KEYS };
