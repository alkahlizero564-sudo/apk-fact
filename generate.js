const fs = require("fs");
const path = require("path");
const { checkHtmlFull } = require("./scripts/check_html");
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// REQUEST_FILE lets scripts/pair.py generate the two apps of a pair without touching request.txt.
const lines = fs.readFileSync(process.env.REQUEST_FILE || "request.txt", "utf8").trim().split("\n");
const clean = (s) => (s || "").trim().toLowerCase().replace(/[^a-z0-9-]/g, "");
const name = clean(lines.shift());

let related = "";
if (lines.length && /^@related:/i.test(lines[0].trim())) {
  related = clean(lines.shift().trim().replace(/^@related:/i, ""));
}

const request = lines.join("\n").trim();
// What the AI reads: without the lines meant only for the build (permissions, sign-in mode), so they never end up
// on a screen. The raw request is still saved and used for the permissions (scripts/perms.py).
const aiRequest = request.replace(/^\s*(ANDROID_PERMISSIONS|LOGIN):.*$/gm, "").trim();
// React apps are also one self-contained index.html (React via CDN), so they build and preview like HTML.
const framework = /^react$/i.test(process.env.GEN_FRAMEWORK || "") ? "react" : "html";
if (!name || !request) {
  console.error("السطر الأول اسم التطبيق (إنجليزي) والباقي الوصف");
  process.exit(1);
}

const dir = path.join("apps", name);
const FILE = path.join(dir, "index.html");
const existing = fs.existsSync(FILE) ? fs.readFileSync(FILE, "utf8") : "";

let relatedCode = "";
if (related && related !== name) {
  const relFile = path.join("apps", related, "index.html");
  if (fs.existsSync(relFile)) {
    relatedCode = fs.readFileSync(relFile, "utf8").slice(0, 80000);
    console.log(`قراءة التطبيق المرتبط: ${relFile}`);
  } else {
    console.log(`التطبيق المرتبط غير موجود: ${relFile}`);
  }
}

const relatedBlock = relatedCode
  ? `\n\nThis app belongs to the SAME project as another app that is already built (the "${related}" app). ` +
    `Read its code carefully first:\n\`\`\`html\n${relatedCode}\n\`\`\`\n` +
    `Keep the new app consistent with it (same visual style, colors, language, and data/field names) ` +
    `and make the two apps work together as parts of one program. The new app's purpose, screens and features ` +
    `come ONLY from its own request below; do not copy the other app's features.\n`
  : "";

// One design bar for every language, shared with the app and scripts/native_langs.py.
const designBrief = JSON.parse(
  fs
    .readFileSync(path.join(__dirname, "services", "designBrief.ts"), "utf8")
    .split("export const DESIGN_BRIEF = ")[1]
    .replace(/;\s*$/, "")
);

const deviceNote =
  "\nDevice features: when the owner asks for the camera, location, microphone, notifications, photos/files, " +
  "vibration, calls or SMS, really implement them with the web APIs (getUserMedia, <input type=file capture>, " +
  "navigator.geolocation, Notification, navigator.vibrate, tel:/sms: links). The Android permissions are added " +
  "automatically; ask right before the feature is used and show a clear message with a retry when refused.\n";

const htmlSystem =
  "You are an expert mobile app designer and web developer. Output ONE complete, self-contained HTML file " +
  "(inline CSS and JS, no external resources), built as a mobile app screen: full-height layout, " +
  "CSS variables for the palette, prefers-color-scheme for dark mode, localStorage for the user's data, " +
  "inline SVG or emoji for icons, and RTL Arabic support when the request is in Arabic.\n\n" +
  designBrief +
  deviceNote +
  "\nReply with ONLY the full file inside a single ```html code block. No explanations.";

const reactSystem =
  "You are an expert mobile app designer and React engineer. Output ONE complete, self-contained index.html that " +
  "is a React 18 single-page mobile app. Load React from a CDN and write JSX — NO build step, NO bundler, NO npm:\n" +
  "- In <head>, load these EXACT pinned scripts in this order: " +
  "https://unpkg.com/react@18.3.1/umd/react.production.min.js then " +
  "https://unpkg.com/react-dom@18.3.1/umd/react-dom.production.min.js then " +
  "https://unpkg.com/@babel/standalone@7.26.4/babel.min.js . You MAY also add https://cdn.tailwindcss.com for styling.\n" +
  "- Put ALL app code in ONE <script type=\"text/babel\" data-presets=\"react\"> … </script> that renders into " +
  "<div id=\"root\"></div> via ReactDOM.createRoot. Use function components and hooks. Babel standalone runs a CLASSIC " +
  "script, so use NO import/export, NO require, NO ES modules: read React, ReactDOM and hooks from globals " +
  "(e.g. const { useState, useEffect, useMemo } = React;).\n" +
  "- Mobile-app feel: full-height layout, CSS variables for the palette, prefers-color-scheme dark mode, a bottom " +
  "tab bar or mobile navigation, large touch targets, smooth CSS transitions, inline SVG or emoji icons, and RTL " +
  "Arabic when the request is Arabic. Persist the user's data with localStorage.\n" +
  "- If a backend is needed, call it with fetch() (for Supabase use the REST API with the given URL and anon key).\n\n" +
  designBrief +
  deviceNote +
  "\nReply with ONLY the full index.html inside a single ```html code block. No explanations.";

const system = framework === "react" ? reactSystem : htmlSystem;

// The design the owner approved in APK Fact (apps/<name>/design.html): build the real app from it.
function designBlock() {
  const f = path.join(dir, "design.html");
  if (!fs.existsSync(f)) return "";
  return (
    "\n\nAPPROVED DESIGN - the owner reviewed and approved this clickable design prototype. Build the real app from it " +
    "so it looks exactly the same (screens, navigation, layout, colors, typography, spacing, icons, texts, components). " +
    "Remove the prototype's top 'screens' switcher (id apkfact-screens): it was only for reviewing. Make every screen " +
    "fully functional with real state and stored data:\n```html\n" +
    fs.readFileSync(f, "utf8").slice(0, 80000) +
    "\n```\n"
  );
}

// Apps of a connected pair: AI updates must keep the shared backend, sign-in and notifications working.
function pairRules() {
  if (!existing || !fs.existsSync(path.join(dir, "pair.json"))) return "";
  const r = require("child_process").spawnSync("python3", [path.join(__dirname, "scripts", "pair.py"), "contract", name], {
    encoding: "utf8",
  });
  return r.status === 0 ? r.stdout : "";
}

const prompt = existing
  ? `Here is the current app:\n\`\`\`html\n${existing}\n\`\`\`${relatedBlock}\n\nApply this change and return the FULL updated file:\n${aiRequest}${pairRules()}`
  : `Create this app:\n${aiRequest}${relatedBlock}${designBlock()}`;

// apps/<name>/meta.json keeps the app's description and every requested change (copied to the vault).
function recordHistory(kind) {
  const metaFile = path.join(dir, "meta.json");
  let meta = { name, lang: framework, history: [] };
  try {
    meta = { ...meta, ...JSON.parse(fs.readFileSync(metaFile, "utf8")) };
  } catch {}
  meta.history.push({ at: new Date().toISOString(), kind, request });
  fs.writeFileSync(metaFile, JSON.stringify(meta, null, 1) + "\n");
}

// Android permissions the description asks for (apps/<name>/perms.txt), see scripts/perms.py.
function savePermissions() {
  const tmp = path.join(require("os").tmpdir(), `request-${process.pid}.txt`);
  try {
    fs.writeFileSync(tmp, request);
    const r = require("child_process").spawnSync("python3", [path.join(__dirname, "scripts", "perms.py"), "save", name, tmp], {
      encoding: "utf8",
    });
    console.log((r.stdout || r.stderr || "").trim());
  } catch (e) {
    console.log(`Permissions not saved: ${e.message}`);
  } finally {
    fs.rmSync(tmp, { force: true });
  }
}

class ApiError extends Error {
  constructor(message, status) {
    super(message);
    this.status = status;
  }
}

async function post(url, options, label) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 300000);
  try {
    const r = await fetch(url, { ...options, signal: ctrl.signal });
    if (!r.ok) {
      const body = await r.text();
      throw new ApiError(`${label} ${r.status}: ${body.slice(0, 600)}`, r.status);
    }
    return await r.json();
  } catch (e) {
    if (e.name === "AbortError") throw new ApiError(`${label}: انتهت المهلة`, 0);
    throw e;
  } finally {
    clearTimeout(timer);
  }
}

async function callClaude(userPrompt = prompt) {
  const d = await post(
    "https://api.anthropic.com/v1/messages",
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": process.env.ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-5-5",
        max_tokens: 16000,
        system,
        messages: [{ role: "user", content: userPrompt }],
      }),
    },
    "Claude"
  );
  return d.content.map((c) => c.text || "").join("");
}

async function callGemini(key, model, userPrompt = prompt) {
  const d = await post(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: "POST",
      headers: { "content-type": "application/json", "x-goog-api-key": key },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: system }] },
        contents: [{ role: "user", parts: [{ text: userPrompt }] }],
      }),
    },
    "Gemini"
  );
  return d.candidates[0].content.parts.map((p) => p.text || "").join("");
}

function extract(text) {
  let code = text;
  const s = text.indexOf("```");
  if (s !== -1) {
    const after = text.indexOf("\n", s) + 1;
    const e = text.lastIndexOf("```");
    code = text.slice(after, e > after ? e : undefined);
  }
  code = code.trim();
  if (!/<html|<!doctype/i.test(code)) throw new Error("الرد ما فيه HTML صالح");
  return code;
}

async function tryProvider(fn, label, tries) {
  let lastErr = "";
  for (let i = 1; i <= tries; i++) {
    try {
      return { code: extract(await fn()) };
    } catch (e) {
      lastErr = String(e.message || e).replace(/\s+/g, " ").slice(0, 200);
      console.log(`${label} المحاولة ${i} فشلت: ${lastErr}`);
      const retryable =
        !(e instanceof ApiError) || [0, 429, 500, 502, 503, 504].includes(e.status);
      if (!retryable) break;
      if (i < tries) await sleep(10000 * i);
    }
  }
  return { error: lastErr };
}

// ---- Gemini: rotate between keys, and fall back to other models when one is busy ----

const geminiKeys = [
  process.env.GEMINI_API_KEY,
  process.env.GEMINI_API_KEY_2,
  process.env.GEMINI_API_KEY_3,
].filter(Boolean);

const primaryModel = process.env.GEMINI_MODEL || "gemini-3.8-flash";
const FALLBACK_MODELS = ["gemini-3.5-flash", "gemini-3.5-flash-lite"];
const geminiModels = [primaryModel, ...FALLBACK_MODELS.filter((m) => m !== primaryModel)];

function classifyGemini(e) {
  const msg = String((e && e.message) || "").toLowerCase();
  const status = e && e.status;
  if (status === 401 || status === 403 || (status === 400 && msg.includes("api key"))) return "invalid";
  if (status === 404) return "gone"; // model retired or unknown: never try it again
  if (status === 429 || msg.includes("resource_exhausted") || msg.includes("quota")) {
    if (msg.includes("perday") || msg.includes("per day") || msg.includes("daily")) return "quota_day";
    return "cooldown";
  }
  return "retry"; // 503, timeout, unknown model, bad output: move to the next model now
}

async function tryGeminiKeys(keys, models, rounds, userPrompt, raw = false) {
  const deadKeys = new Set();
  const deadPairs = new Set();
  const deadModels = new Set();
  const cooldown = new Map();
  let lastErr = "";
  for (let round = 0; round < rounds; round++) {
    for (const model of models) {
      if (deadModels.has(model)) continue;
      for (let n = 0; n < keys.length; n++) {
        const key = keys[n];
        const pair = `${n}|${model}`;
        if (deadKeys.has(key) || deadPairs.has(pair) || (cooldown.get(pair) || 0) > Date.now()) continue;
        try {
          const text = await callGemini(key, model, userPrompt);
          return { code: raw ? text : extract(text), model };
        } catch (e) {
          lastErr = String((e && e.message) || e).replace(/\s+/g, " ").slice(0, 200);
          const kind = classifyGemini(e);
          console.log(`Gemini [${model}] المفتاح ${n + 1} فشل (${kind}): ${lastErr}`);
          if (kind === "invalid") deadKeys.add(key);
          else if (kind === "gone") { deadModels.add(model); break; }
          else if (kind === "quota_day") deadPairs.add(pair);
          else if (kind === "cooldown") cooldown.set(pair, Date.now() + 60000);
          else break; // model busy or unreachable: go to the next model right away
        }
      }
    }
    const allDead = models.every((m) =>
      deadModels.has(m) || keys.every((k, n) => deadKeys.has(k) || deadPairs.has(`${n}|${m}`))
    );
    if (allDead) break;
    if (round < rounds - 1) {
      const wait = Math.min(10000 * 2 ** round, 60000);
      console.log(`لا يوجد نموذج أو مفتاح متاح الآن، انتظار ${wait / 1000} ثانية`);
      await sleep(wait);
    }
  }
  return { error: lastErr };
}

async function runProvider(label, userPrompt = prompt) {
  if (label === "Claude") {
    if (!process.env.ANTHROPIC_API_KEY) {
      return { error: "المفتاح ANTHROPIC_API_KEY غير موجود في الأسرار" };
    }
    return tryProvider(() => callClaude(userPrompt), "Claude", 3);
  }
  if (geminiKeys.length === 0) {
    return { error: "المفتاح GEMINI_API_KEY غير موجود في الأسرار" };
  }
  return tryGeminiKeys(geminiKeys, geminiModels, 3, userPrompt);
}

// Up to 3 repair rounds when the generated app has JavaScript errors (syntax, or errors thrown when it runs and
// its buttons are pressed); keeps the version with the fewest errors.
async function repair(code, problems, order) {
  let best = { code, problems };
  let hist = [];
  for (let round = 1; round <= 3 && best.problems.length; round++) {
    console.log(`الكود فيه أخطاء JavaScript (محاولة إصلاح ${round} من 3):\n` + best.problems.join("\n"));
    const fixPrompt =
      `This HTML app has JavaScript errors, found by checking its code and by running it headless and pressing ` +
      `its buttons. Fix them with the smallest possible changes, keep the design, texts and behavior the same, and ` +
      `return the FULL corrected file.\nHints: a ReferenceError means a function or variable is missing or ` +
      `misspelled: define it at the top level of the script (not inside another function) with exactly the name ` +
      `the HTML uses; "Cannot read properties of null" means an element id that does not exist or a script that ` +
      `runs before the element exists; wrap JSON.parse/localStorage reads in try/catch with a default.\n\nERRORS:\n` +
      `${best.problems.join("\n")}` +
      (hist.length ? `\n\nA previous fix attempt still had these (try another way):\n${hist.join("\n")}` : "") +
      `\n\nFILE:\n\`\`\`html\n${best.code}\n\`\`\``;
    let improved = false;
    for (const label of order) {
      const res = await runProvider(label, fixPrompt);
      if (!res.code) continue;
      const left = await checkHtmlFull(res.code);
      if (left.length < best.problems.length) {
        console.log(left.length ? `اتصلح جزء، باقي: ${left.join(" | ")}` : "اتصلحت أخطاء JavaScript");
        best = { code: res.code, problems: left };
        improved = true;
        break;
      }
      hist = left.slice(0, 4);
    }
    if (!improved) break;
  }
  if (best.problems.length) console.log("ما قدرنا نصلح كل أخطاء JavaScript، بنحفظ أفضل نسخة");
  return best.code;
}

// Checks that the app does everything the owner asked; when something is missing, one more round adds it.
async function completeRequirements(code, order) {
  if (geminiKeys.length === 0) return code;
  const what = existing ? "the CHANGE the owner asked for" : "the owner's request";
  const check = await tryGeminiKeys(
    geminiKeys,
    geminiModels,
    2,
    `You review an app against ${what}. List every concrete requirement in it (features, screens, fields, ` +
      `buttons, texts, names, numbers, rules) that the code does NOT implement, or implements differently ` +
      `from what was asked. Ignore style details the owner did not mention. Reply with JSON only: ` +
      `{"missing": ["..."]} (an empty list when everything is done).\n\nOWNER'S REQUEST:\n${aiRequest}\n\nCODE:\n` +
      "```html\n" + code + "\n```",
    true
  );
  let missing = [];
  try {
    missing = JSON.parse((check.code || "").replace(/^[^{]*/, "").replace(/[^}]*$/, "")).missing || [];
  } catch {
    return code;
  }
  missing = missing.filter((m) => typeof m === "string" && m.trim()).slice(0, 15);
  if (!missing.length) {
    console.log("مراجعة الطلب: كل المطلوب منفّذ");
    return code;
  }
  console.log("مراجعة الطلب: ناقص\n- " + missing.join("\n- "));
  const fixPrompt =
    `${prompt}\n\nYour previous version is below, but it does not do all of what the owner asked. Missing or ` +
    `different:\n- ${missing.join("\n- ")}\n\nReturn the FULL file again with ALL of these implemented exactly ` +
    `as asked, keeping everything else.\n\nPREVIOUS VERSION:\n` + "```html\n" + code + "\n```";
  for (const label of order) {
    const res = await runProvider(label, fixPrompt);
    if (res.code) {
      console.log("اتضاف الناقص");
      return res.code;
    }
  }
  return code;
}

// On a fresh build, make the app match the design the owner approved (not only the feature list): the reported
// "the installed app did not look like the preview". One repair round fixes the visible differences.
async function matchDesign(code, order) {
  if (geminiKeys.length === 0 || existing) return code;
  const f = path.join(dir, "design.html");
  if (!fs.existsSync(f)) return code;
  const design = fs.readFileSync(f, "utf8").slice(0, 80000);
  const check = await tryGeminiKeys(
    geminiKeys,
    geminiModels,
    2,
    `The owner reviewed and APPROVED the design prototype below (an HTML clickable mock). An app was then built ` +
      `to match it. List every difference the user WOULD SEE: screens in the design that are missing or clearly ` +
      `different in the app, and differences in layout, structure, colors, typography, spacing, corner radius, ` +
      `icons, components, texts and navigation. Ignore the top reviewer switcher (id apkfact-screens) and tiny ` +
      `pixel differences. Be concrete (name the screen and what differs). Reply with JSON only: ` +
      `{"diffs": ["..."]} (an empty list when the app already looks like the design).\n\nAPPROVED DESIGN:\n` +
      "```html\n" + design + "\n```\n\nAPP CODE:\n" + "```html\n" + code + "\n```",
    true
  );
  let diffs = [];
  try {
    diffs = JSON.parse((check.code || "").replace(/^[^{]*/, "").replace(/[^}]*$/, "")).diffs || [];
  } catch {
    return code;
  }
  diffs = diffs.filter((d) => typeof d === "string" && d.trim()).slice(0, 15);
  if (!diffs.length) {
    console.log("مراجعة التصميم: التطبيق مطابق للتصميم المعتمد");
    return code;
  }
  console.log("يختلف عن التصميم المعتمد:\n- " + diffs.join("\n- "));
  const fixPrompt =
    `${prompt}\n\nYour previous version is below, but it looks different from the APPROVED design in these ways:\n- ` +
    `${diffs.join("\n- ")}\n\nReturn the FULL file again, fixing every one so it matches the design exactly (same ` +
    `screens, layout, colors, typography, spacing, corner radius, icons, texts and components), keeping all ` +
    `features and stored data working.\n\nPREVIOUS VERSION:\n` + "```html\n" + code + "\n```";
  for (const label of order) {
    const res = await runProvider(label, fixPrompt);
    if (res.code) {
      console.log("قرّبنا التطبيق من التصميم المعتمد");
      return res.code;
    }
  }
  return code;
}

(async () => {
  const order = process.env.AI_PROVIDER === "gemini" ? ["Gemini", "Claude"] : ["Claude", "Gemini"];

  const failures = [];
  for (const label of order) {
    const res = await runProvider(label);
    if (res.code) {
      res.code = await completeRequirements(res.code, order);
      res.code = await matchDesign(res.code, order);
      const problems = await checkHtmlFull(res.code);
      if (problems.length) res.code = await repair(res.code, problems, order);
      fs.mkdirSync(dir, { recursive: true });
      fs.writeFileSync(FILE, res.code);
      recordHistory(existing ? "edit" : "create");
      savePermissions();
      console.log(`تم: ${FILE} بواسطة ${label}${res.model ? " (" + res.model + ")" : ""}`);
      return;
    }
    failures.push(`${label}: ${res.error}`);
  }

  console.error("ملخص الفشل:");
  for (const f of failures) console.error(f);
  process.exit(1);
})();
