const fs = require("fs");
const FILE = "index.html";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let request = fs.readFileSync("request.txt", "utf8").trim();
if (!request) { console.error("request.txt فاضي"); process.exit(1); }

const isNew = request.startsWith("جديد:");
if (isNew) request = request.slice(5).trim();
const existing = !isNew && fs.existsSync(FILE) ? fs.readFileSync(FILE, "utf8") : "";

const system =
  "You are an expert web developer. Output ONE complete, self-contained HTML file " +
  "(inline CSS and JS), mobile-friendly, RTL Arabic support. " +
  "Reply with ONLY the full file inside a single ```html code block. No explanations.";

const prompt = existing
  ? `Here is the current app:\n\`\`\`html\n${existing}\n\`\`\`\n\nApply this change and return the FULL updated file:\n${request}`
  : `Create this app:\n${request}`;

async function callClaude() {
  const r = await fetch("https://api.anthropic.com/v1/messages", {
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
  });
  if (!r.ok) throw new Error(`Claude ${r.status}: ${await r.text()}`);
  const d = await r.json();
  return d.content.map((c) => c.text || "").join("");
}

async function callGemini() {
  const model = "gemini-2.5-flash";
  const r = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${process.env.GEMINI_API_KEY}`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: system }] },
        contents: [{ role: "user", parts: [{ text: prompt }] }],
      }),
    }
  );
  if (!r.ok) throw new Error(`Gemini ${r.status}: ${await r.text()}`);
  const d = await r.json();
  return d.candidates[0].content.parts.map((p) => p.text || "").join("");
}

function extract(text) {
  let code = text;
  const s = text.indexOf("```");
  if (s !== -1) {
    const afterFence = text.indexOf("\n", s) + 1;
    const e = text.lastIndexOf("```");
    code = text.slice(afterFence, e > afterFence ? e : undefined);
  }
  code = code.trim();
  if (!/<html|<!doctype/i.test(code)) throw new Error("الرد ما فيه HTML صالح");
  return code;
}

async function tryProvider(fn, name, tries = 4) {
  for (let i = 1; i <= tries; i++) {
    try {
      return extract(await fn());
    } catch (e) {
      console.log(`${name} المحاولة ${i} فشلت: ${String(e).slice(0, 200)}`);
      if (i < tries) await sleep(3000 * i);
    }
  }
  return null;
}

(async () => {
  const order = process.env.AI_PROVIDER === "gemini"
    ? [["Gemini", callGemini, "GEMINI_API_KEY"], ["Claude", callClaude, "ANTHROPIC_API_KEY"]]
    : [["Claude", callClaude, "ANTHROPIC_API_KEY"], ["Gemini", callGemini, "GEMINI_API_KEY"]];

  for (const [name, fn, key] of order) {
    if (!process.env[key]) continue;
    const code = await tryProvider(fn, name);
    if (code) {
      fs.writeFileSync(FILE, code);
      console.log(`تم التوليد بواسطة ${name}`);
      return;
    }
  }
  console.error("فشل التوليد من كل المزودين");
  process.exit(1);
})();
