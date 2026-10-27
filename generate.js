const fs = require("fs");
const path = require("path");
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const lines = fs.readFileSync("request.txt", "utf8").trim().split("\n");
const clean = (s) => (s || "").trim().toLowerCase().replace(/[^a-z0-9-]/g, "");
const name = clean(lines.shift());

let related = "";
if (lines.length && /^@related:/i.test(lines[0].trim())) {
  related = clean(lines.shift().trim().replace(/^@related:/i, ""));
}

const request = lines.join("\n").trim();
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
    `and make the two apps work together as parts of one program.\n`
  : "";

const system =
  "You are an expert web developer. Output ONE complete, self-contained HTML file " +
  "(inline CSS and JS), mobile-friendly, with RTL Arabic support when the request is in Arabic. " +
  "Reply with ONLY the full file inside a single ```html code block. No explanations.";

const prompt = existing
  ? `Here is the current app:\n\`\`\`html\n${existing}\n\`\`\`${relatedBlock}\n\nApply this change and return the FULL updated file:\n${request}`
  : `Create this app:\n${request}${relatedBlock}`;

class ApiError extends Error {
  constructor(message, status) {
    super(message);
    this.status = status;
  }
}

async function post(url, options, label) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 150000);
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

async function callClaude() {
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
        messages: [{ role: "user", content: prompt }],
      }),
    },
    "Claude"
  );
  return d.content.map((c) => c.text || "").join("");
}

async function callGemini(key) {
  const model = process.env.GEMINI_MODEL || "gemini-3.8-flash";
  const d = await post(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: "POST",
      headers: { "content-type": "application/json", "x-goog-api-key": key },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: system }] },
        contents: [{ role: "user", parts: [{ text: prompt }] }],
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

// ---- Gemini: rotate between keys when one runs out ----

const geminiKeys = [
  process.env.GEMINI_API_KEY,
  process.env.GEMINI_API_KEY_2,
  process.env.GEMINI_API_KEY_3,
].filter(Boolean);

function classifyGemini(e) {
  const msg = String((e && e.message) || "").toLowerCase();
  const status = e && e.status;
  if (status === 429 || msg.includes("resource_exhausted") || msg.includes("quota")) {
    if (msg.includes("perday") || msg.includes("per day") || msg.includes("daily")) return "dead";
    return "cooldown";
  }
  if (status === 401 || status === 403 || (status === 400 && msg.includes("api key"))) return "dead";
  return "retry";
}

async function tryGeminiKeys(keys, rounds) {
  const dead = new Set();
  const cooldown = new Map();
  let lastErr = "";
  for (let round = 0; round < rounds; round++) {
    for (let n = 0; n < keys.length; n++) {
      const key = keys[n];
      if (dead.has(key) || (cooldown.get(key) || 0) > Date.now()) continue;
      try {
        return { code: extract(await callGemini(key)) };
      } catch (e) {
        lastErr = String((e && e.message) || e).replace(/\s+/g, " ").slice(0, 200);
        const kind = classifyGemini(e);
        console.log(`Gemini المفتاح ${n + 1} فشل (${kind}): ${lastErr}`);
        if (kind === "dead") dead.add(key);
        else if (kind === "cooldown") cooldown.set(key, Date.now() + 60000);
      }
    }
    if (dead.size === keys.length) break;
    if (round < rounds - 1) {
      const wait = Math.min(15000 * 2 ** round, 90000);
      console.log(`لا يوجد مفتاح متاح الآن، انتظار ${wait / 1000} ثانية`);
      await sleep(wait);
    }
  }
  return { error: lastErr };
}

async function runProvider(label) {
  if (label === "Claude") {
    if (!process.env.ANTHROPIC_API_KEY) {
      return { error: "المفتاح ANTHROPIC_API_KEY غير موجود في الأسرار" };
    }
    return tryProvider(callClaude, "Claude", 3);
  }
  if (geminiKeys.length === 0) {
    return { error: "المفتاح GEMINI_API_KEY غير موجود في الأسرار" };
  }
  return tryGeminiKeys(geminiKeys, 4);
}

(async () => {
  const order = process.env.AI_PROVIDER === "gemini" ? ["Gemini", "Claude"] : ["Claude", "Gemini"];

  const failures = [];
  for (const label of order) {
    const res = await runProvider(label);
    if (res.code) {
      fs.mkdirSync(dir, { recursive: true });
      fs.writeFileSync(FILE, res.code);
      console.log(`تم: ${FILE} بواسطة ${label}`);
      return;
    }
    failures.push(`${label}: ${res.error}`);
  }

  console.error("ملخص الفشل:");
  for (const f of failures) console.error(f);
  process.exit(1);
})();
