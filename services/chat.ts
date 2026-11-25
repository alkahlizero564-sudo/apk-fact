// "Build by chatting": a conversation with the AI that gathers the app idea, asks a couple of short questions,
// fills in anything the owner leaves out, and — when it has enough — emits a structured spec the app turns into a
// real app (one app, or a connected customer+admin pair). Multi-turn Gemini, with the same keys/models as the rest.
import * as SecureStore from "expo-secure-store";
import { modelOrder, isExhausted, noteFailure } from "./geminiModels";
import { Lang, LANGS } from "./langs";
import { AiImage } from "./instantPreview";
import { thinkingConfigFor, markThinkingUnsupported } from "./geminiThink";

export type ChatMsg = { role: "user" | "model"; text: string };
export type ChatSpec = {
  name: string; // english slug a-z0-9-
  title: string; // the app's shown name (can be Arabic)
  lang: Lang;
  pair: boolean; // one app, or a connected customer+admin pair
  admins: string; // for a pair: the admin email(s), comma separated
  description: string; // the full, detailed brief in the owner's language
};

// Speed: fastest model first (the owner's explicit GEMINI_MODEL still wins when set), stronger ones as fallback.
const MODELS = ["gemini-3.5-flash-lite", "gemini-3.8-flash", "gemini-3.5-flash"];
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function keys(): Promise<string[]> {
  const out: string[] = [];
  for (const k of ["GEMINI_API_KEY", "GEMINI_API_KEY_2", "GEMINI_API_KEY_3"]) {
    const v = await SecureStore.getItemAsync(k);
    if (v) out.push(v);
  }
  if (!out.length) throw new Error("أضف مفتاح Gemini من الإعدادات أولاً.");
  return out;
}

const SYSTEM = `You are a warm, concise Arabic assistant inside "APK Fact" that builds a mobile app for the owner by chatting.
The owner tells you an idea; you turn it into a real app — either ONE app, or a connected PAIR (a customer app + an admin app on one backend).

How to talk:
- Always answer in simple, friendly Arabic. Keep each message short.
- Ask only what you really need, ONE or TWO short questions at a time (what the app does, its main screens/features, one app or two connected apps). Do NOT interrogate — 2 to 4 short exchanges are plenty.
- Fill in anything the owner does not say with sensible defaults and state your assumption in one short line so they can correct it. Never block waiting for details you can reasonably assume.
- Choose the language yourself unless the owner asks: "html" for simple apps / stores / menus / info apps, "react" for modern interactive UIs, "flutter" for full native-feeling apps. For a connected pair, ask for ONE admin email (the person who manages it).
- When (and only when) you have enough to build, write a one-line Arabic summary, then output EXACTLY ONE fenced json block, nothing after it:
\`\`\`json
{"ready": true, "name": "<short english slug, a-z 0-9 and - only>", "title": "<app name, can be Arabic>", "lang": "html|react|flutter|python|kotlin", "pair": false, "admins": "", "description": "<a full, detailed brief in Arabic: every screen, feature, data field, button, text, colors, and the audience — build EXACTLY this>"}
\`\`\`
Rules for the json: output it ONLY when ready to build (otherwise keep chatting with no json). "name" is lowercase english letters, digits and - only. For a pair set "pair": true and put the admin email in "admins". Make "description" rich and specific so the app is complete.`;

async function callOnce(key: string, model: string, contents: any[]): Promise<string> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 120000);
  try {
    // Speed: skip the model's slow "thinking" phase (self-heals to the normal path if a model rejects it).
    const think = await thinkingConfigFor(model);
    const send = async (useThink: boolean) =>
      fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
        method: "POST",
        headers: { "content-type": "application/json", "x-goog-api-key": key },
        body: JSON.stringify({ systemInstruction: { parts: [{ text: SYSTEM }] }, contents, generationConfig: { temperature: 0.6, ...(useThink && think ? think : {}) } }),
        signal: ctrl.signal,
      });
    let res = await send(true);
    if (res.status === 400 && think) {
      await markThinkingUnsupported(model);
      res = await send(false);
    }
    // The body says WHY (e.g. "limit per day"), so a used-up model is skipped for the rest of the day.
    if (!res.ok) throw Object.assign(new Error(`Gemini ${res.status}: ${(await res.text()).slice(0, 300)}`), { status: res.status });
    const data = await res.json();
    const parts = data?.candidates?.[0]?.content?.parts ?? [];
    const text = parts.map((p: any) => p.text || "").join("").trim();
    if (!text) throw new Error("رد فارغ");
    return text;
  } finally {
    clearTimeout(timer);
  }
}

/** The AI's next message given the whole conversation so far. `images` are reference pictures the owner attached
 *  (sent as vision input on the latest user message). */
export async function chatReply(history: ChatMsg[], images: AiImage[] = []): Promise<string> {
  const ks = await keys();
  const chosen = (await SecureStore.getItemAsync("GEMINI_MODEL")) || MODELS[0];
  const models = await modelOrder([chosen, ...MODELS], ks); // then every other model the keys can use
  const contents: any[] = history.map((m) => ({ role: m.role, parts: [{ text: m.text }] as any[] }));
  // Attach the picture(s) to the owner's most recent message so the AI sees what they mean.
  if (images.length) {
    for (let i = contents.length - 1; i >= 0; i--) {
      if (contents[i].role === "user") {
        contents[i].parts = [...images.map((im) => ({ inline_data: { mime_type: im.mime || "image/jpeg", data: im.data } })), ...contents[i].parts];
        break;
      }
    }
  }
  let last = "";
  for (let round = 0; round < 2; round++) {
    for (const model of models) {
      for (const key of ks) {
        if (await isExhausted(key, model)) continue; // this model's daily quota is used up on this key
        try {
          return await callOnce(key, model, contents);
        } catch (e: any) {
          last = e?.message ?? String(e);
          await noteFailure(key, model, e?.status, last);
          if (e?.status === 404) break;
        }
      }
    }
    if (round === 0) await sleep(6000);
  }
  throw new Error(`ما قدرنا نكمّل: ${last}`);
}

/** Pulls the final build spec out of the AI's message, or null while it is still chatting. */
export function extractSpec(reply: string): ChatSpec | null {
  const m = reply.match(/```json\s*([\s\S]*?)```/i) || reply.match(/(\{[\s\S]*"ready"[\s\S]*\})/);
  if (!m) return null;
  try {
    const o = JSON.parse(m[1]);
    if (!o || o.ready !== true) return null;
    const name = String(o.name || "").toLowerCase().replace(/[^a-z0-9-]/g, "").replace(/^-+|-+$/g, "").slice(0, 30);
    const lang: Lang = (o.lang in LANGS ? o.lang : "html") as Lang;
    const description = String(o.description || "").trim();
    if (!name || description.length < 10) return null;
    return {
      name,
      title: String(o.title || name).trim().slice(0, 60),
      lang,
      pair: o.pair === true,
      admins: String(o.admins || "").trim(),
      description,
    };
  } catch {
    return null;
  }
}

/** The AI message to show the owner, without the raw json block. */
export function stripSpec(reply: string): string {
  return reply.replace(/```json[\s\S]*?```/i, "").replace(/\{[\s\S]*"ready"[\s\S]*\}\s*$/, "").trim();
}
