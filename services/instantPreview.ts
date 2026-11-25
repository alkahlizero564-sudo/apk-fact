// Instant previews straight from the phone (no GitHub run): the AI writes one HTML file that is
// the app (HTML) or a faithful interactive imitation of it (Flutter / Python). Results are cached.
import AsyncStorage from "@react-native-async-storage/async-storage";
import * as SecureStore from "expo-secure-store";
import { modelOrder, isExhausted, noteFailure } from "./geminiModels";
import { Lang } from "./langs";
import { DESIGN_BRIEF } from "./designBrief";
import { thinkingConfigFor, markThinkingUnsupported } from "./geminiThink";

// A reference image the owner attached to their description (base64 + mime), sent to the AI as vision input.
export type AiImage = { data: string; mime: string };

// Speed: the fastest model is tried first for the interactive steps (preview/design/understand), falling back to
// the stronger ones only if it fails. The owner's explicit model choice (GEMINI_MODEL) still wins when set.
const FAST_MODEL = "gemini-3.5-flash-lite";
const FALLBACK_MODELS = [FAST_MODEL, "gemini-3.8-flash", "gemini-3.5-flash"];
const CACHE_PREFIX = "instant-preview:";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

function hash(s: string) {
  let h = 5381;
  for (let i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) | 0;
  return (h >>> 0).toString(36);
}

function systemFor(lang: Lang) {
  const what =
    lang === "html"
      ? "Build the app itself as ONE complete, self-contained HTML file (inline CSS and JS)."
      : lang === "react"
      ? "Build the app itself as ONE complete, self-contained index.html using React 18 + ReactDOM + Babel (JSX) loaded from a CDN (no build step): a single-page mobile app with components and hooks, styled to look and behave like a native mobile app in a WebView."
      : `Build an interactive PREVIEW of a ${lang === "flutter" ? "Flutter (Material 3)" : lang === "kotlin" ? "native Android Kotlin Jetpack Compose (Material 3)" : "Python Flet (Material 3)"} ` +
        "mobile app as ONE self-contained HTML file (inline CSS and JS) that looks and behaves like that native app: " +
        "Material 3 components, app bar, bottom navigation, cards, FAB, ripple-like pressed states.";
  return (
    `You are an expert mobile app designer and front-end developer. ${what} ` +
    "Mobile-first full-height layout, no external resources (inline SVG or emoji icons), working navigation, " +
    "buttons, forms and lists with realistic sample data, localStorage for state. RTL Arabic when the request is Arabic.\n\n" +
    DESIGN_BRIEF +
    "\nReply with ONLY the file inside a single ```html code block."
  );
}

function extractHtml(text: string) {
  const m = text.match(/```html[ \t]*\n([\s\S]*?)\n```/i) || text.match(/```[\w-]*[ \t]*\n([\s\S]*?)\n```/);
  const code = (m ? m[1] : text).trim();
  if (!/<html|<!doctype/i.test(code)) throw new Error("الرد ما فيه صفحة HTML");
  return code;
}

async function geminiKeys() {
  const keys: string[] = [];
  for (const k of ["GEMINI_API_KEY", "GEMINI_API_KEY_2", "GEMINI_API_KEY_3"]) {
    const v = await SecureStore.getItemAsync(k);
    if (v) keys.push(v);
  }
  if (!keys.length) throw new Error("أضف مفتاح Gemini من الإعدادات الأول.");
  return keys;
}

async function callGemini(key: string, model: string, system: string, prompt: string, temperature = 0.5, images: AiImage[] = []) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 180000);
  try {
    // Reference images the owner attached go first (as vision input), then the text prompt.
    const userParts: any[] = images.map((im) => ({ inline_data: { mime_type: im.mime || "image/jpeg", data: im.data } }));
    userParts.push({ text: prompt });
    // Speed: skip the model's slow "thinking" phase for this generation task (self-heals if unsupported).
    const think = await thinkingConfigFor(model);
    const send = async (useThink: boolean) =>
      fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
        method: "POST",
        headers: { "content-type": "application/json", "x-goog-api-key": key },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: system }] },
          contents: [{ role: "user", parts: userParts }],
          generationConfig: { temperature, ...(useThink && think ? think : {}) },
        }),
        signal: ctrl.signal,
      });
    let res = await send(true);
    // If turning thinking off is the reason for a 400, remember that and retry the normal way (never break).
    if (res.status === 400 && think) {
      await markThinkingUnsupported(model);
      res = await send(false);
    }
    if (!res.ok) throw Object.assign(new Error(`Gemini ${res.status}: ${(await res.text()).slice(0, 300)}`), { status: res.status });
    const data = await res.json();
    const parts = data?.candidates?.[0]?.content?.parts ?? [];
    return parts.map((p: any) => p.text || "").join("");
  } catch (e: any) {
    if (e?.name === "AbortError") throw Object.assign(new Error("انتهت المهلة"), { status: 0 });
    throw e;
  } finally {
    clearTimeout(timer);
  }
}

// Streaming: React Native's fetch can't read a response as it arrives, so we use XMLHttpRequest against Gemini's
// streamGenerateContent (SSE). onText gets the whole text so far on every chunk, so the UI can show the design
// being written live. Rejects with {status} like callGemini so the caller can fall back or switch model/key.
function callGeminiStream(
  key: string,
  model: string,
  system: string,
  prompt: string,
  temperature: number,
  images: AiImage[],
  onText: (full: string) => void,
  think: Record<string, unknown> | null
): Promise<string> {
  return new Promise((resolve, reject) => {
    const userParts: any[] = images.map((im) => ({ inline_data: { mime_type: im.mime || "image/jpeg", data: im.data } }));
    userParts.push({ text: prompt });
    const xhr = new XMLHttpRequest();
    xhr.open("POST", `https://generativelanguage.googleapis.com/v1beta/models/${model}:streamGenerateContent?alt=sse`);
    xhr.setRequestHeader("content-type", "application/json");
    xhr.setRequestHeader("x-goog-api-key", key);
    xhr.timeout = 180000;
    let seen = 0;
    let buffer = "";
    let full = "";
    const pump = () => {
      const all = xhr.responseText || "";
      if (all.length <= seen) return;
      buffer += all.slice(seen);
      seen = all.length;
      let idx: number;
      while ((idx = buffer.indexOf("\n")) >= 0) {
        const line = buffer.slice(0, idx).trim();
        buffer = buffer.slice(idx + 1);
        if (!line.startsWith("data:")) continue;
        const payload = line.slice(5).trim();
        if (!payload || payload === "[DONE]") continue;
        try {
          const obj = JSON.parse(payload);
          const t = (obj?.candidates?.[0]?.content?.parts ?? []).map((p: any) => p.text || "").join("");
          if (t) {
            full += t;
            onText(full);
          }
        } catch {
          // a line that isn't complete JSON yet — ignore; the rest arrives next chunk
        }
      }
    };
    xhr.onprogress = pump;
    xhr.onreadystatechange = () => {
      if (xhr.readyState >= 3) pump();
    };
    xhr.onload = () => {
      pump();
      if (xhr.status >= 200 && xhr.status < 300) resolve(full);
      else reject(Object.assign(new Error(`Gemini ${xhr.status}: ${String(xhr.responseText || "").slice(0, 300)}`), { status: xhr.status }));
    };
    xhr.onerror = () => reject(Object.assign(new Error("تعذّر الاتصال"), { status: 0 }));
    xhr.ontimeout = () => reject(Object.assign(new Error("انتهت المهلة"), { status: 0 }));
    xhr.send(
      JSON.stringify({
        systemInstruction: { parts: [{ text: system }] },
        contents: [{ role: "user", parts: userParts }],
        generationConfig: { temperature, ...(think ? think : {}) },
      })
    );
  });
}

// Strip a leading ```lang fence from partial text so the live HTML renders cleanly before the reply is complete.
function livePartial(t: string): string {
  const f = t.indexOf("```");
  if (f >= 0) {
    const nl = t.indexOf("\n", f);
    return nl >= 0 ? t.slice(nl + 1) : "";
  }
  return t;
}

export async function cachedPreview(lang: Lang, description: string) {
  try {
    return await AsyncStorage.getItem(CACHE_PREFIX + hash(lang + "|" + description));
  } catch {
    return null;
  }
}

/** Returns preview HTML; uses the cache unless fresh is true. onStatus gets short Arabic progress lines. */
export async function instantPreview(
  lang: Lang,
  description: string,
  onStatus: (s: string) => void,
  fresh = false,
  images: AiImage[] = [],
  onPartial?: (html: string) => void
): Promise<string> {
  const key = CACHE_PREFIX + hash(lang + "|" + description);
  // An attached reference image is not part of the cache key, so always draw fresh when one is given.
  if (!fresh && !images.length) {
    const hit = await cachedPreview(lang, description);
    if (hit) return hit;
  }
  const prompt =
    `App description:\n${description}` +
    (images.length ? "\n\nThe owner attached the image(s) above as a visual reference — follow its look, layout, colors and style where it fits this app." : "");
  const html = await askGeminiHtml(systemFor(lang), prompt, onStatus, "يرسم المعاينة", 0.5, images, onPartial);
  if (!images.length) await AsyncStorage.setItem(key, html).catch(() => {});
  return html;
}

/** Asks Gemini (chosen model first, then fallbacks; every key) for one HTML file. */
export async function askGeminiHtml(
  system: string,
  prompt: string,
  onStatus: (s: string) => void,
  doing = "يشتغل",
  temperature = 0.5,
  images: AiImage[] = [],
  onPartial?: (html: string) => void
): Promise<string> {
  return askGemini(system, prompt, onStatus, doing, temperature, extractHtml, images, onPartial);
}

/**
 * Asks Gemini (chosen model first, then fallbacks; every key). `parse` turns the reply into the result;
 * when it throws (bad reply), the next model/key is tried.
 */
export async function askGemini<T = string>(
  system: string,
  prompt: string,
  onStatus: (s: string) => void,
  doing = "يشتغل",
  temperature = 0.5,
  parse: (text: string) => T = (t) => t as unknown as T,
  images: AiImage[] = [],
  onPartial?: (text: string) => void
): Promise<T> {
  const keys = await geminiKeys();
  const chosen = (await SecureStore.getItemAsync("GEMINI_MODEL")) || FALLBACK_MODELS[0];
  const models = await modelOrder([chosen, ...FALLBACK_MODELS], keys); // then every other model the keys can use
  let last = "";
  for (let round = 0; round < 2; round++) {
    for (const model of models) {
      for (let k = 0; k < keys.length; k++) {
        if (await isExhausted(keys[k], model)) continue; // this model's daily quota is used up on this key
        onStatus(`الذكاء الاصطناعي ${doing}… (${model}${keys.length > 1 ? `، مفتاح ${k + 1}` : ""})`);
        try {
          let text: string;
          if (onPartial) {
            // Stream the reply so the UI can show it being written; fall back to a normal call on a stream hiccup.
            const think = await thinkingConfigFor(model);
            try {
              text = await callGeminiStream(keys[k], model, system, prompt, temperature, images, (p) => onPartial(livePartial(p)), think);
              if (!text.trim()) text = await callGemini(keys[k], model, system, prompt, temperature, images); // empty stream: normal call
            } catch (se: any) {
              if (se?.status === 400 && think) await markThinkingUnsupported(model);
              if (se?.status === 404 || se?.status === 401 || se?.status === 403) throw se; // let the loop switch model/key
              text = await callGemini(keys[k], model, system, prompt, temperature, images);
            }
          } else {
            text = await callGemini(keys[k], model, system, prompt, temperature, images);
          }
          return parse(text);
        } catch (e: any) {
          last = e?.message ?? String(e);
          await noteFailure(keys[k], model, e?.status, last);
          if (e?.status === 404) break; // model not available: next model
          if (e?.status === 401 || e?.status === 403) continue; // bad key: next key
        }
      }
    }
    if (round === 0) {
      onStatus("الخدمة مزدحمة، بنحاول تاني بعد ثواني…");
      await sleep(8000);
    }
  }
  throw new Error(`ما قدرنا نكمّل: ${last}`);
}
