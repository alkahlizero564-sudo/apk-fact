import * as SecureStore from "expo-secure-store";

const SYSTEM =
  "You are an expert web developer. Output ONE complete, self-contained HTML file " +
  "(inline CSS and JS), mobile-friendly, with RTL Arabic support when the request is in Arabic. " +
  "Reply with ONLY the full file inside a single ```html code block. No explanations.";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

function explain(label: string, status: number, body: string): string {
  const b = body.toLowerCase();
  if (status === 0) return `${label}: انتهت المهلة`;
  if (b.includes("credit balance")) return `${label}: الرصيد خلص`;
  if (status === 401 || status === 403 || b.includes("api key not valid") || b.includes("api_key_invalid"))
    return `${label}: المفتاح غير صالح`;
  if (status === 429) return `${label}: وصلت حد الاستخدام`;
  if (status === 503 || status === 529) return `${label}: الخدمة مزدحمة`;
  if (status === 404) return `${label}: النموذج غير متاح (${body.slice(0, 120)})`;
  return `${label} ${status}: ${body.slice(0, 160)}`;
}

async function postJson(url: string, headers: Record<string, string>, body: any, label: string) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 240000);
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json", ...headers },
      body: JSON.stringify(body),
      signal: ctrl.signal,
    });
    if (!res.ok) {
      const text = await res.text();
      throw Object.assign(new Error(explain(label, res.status, text)), { status: res.status });
    }
    return await res.json();
  } catch (e: any) {
    if (e && e.name === "AbortError") {
      throw Object.assign(new Error(explain(label, 0, "")), { status: 0 });
    }
    throw e;
  } finally {
    clearTimeout(timer);
  }
}

async function callClaude(key: string, prompt: string): Promise<string> {
  const d = await postJson(
    "https://api.anthropic.com/v1/messages",
    { "x-api-key": key, "anthropic-version": "2023-06-01" },
    {
      model: "claude-sonnet-5-5",
      max_tokens: 12000,
      system: SYSTEM,
      messages: [{ role: "user", content: prompt }],
    },
    "Claude"
  );
  return (d.content || []).map((c: any) => c.text || "").join("");
}

async function callGemini(key: string, prompt: string): Promise<string> {
  const d = await postJson(
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent",
    { "x-goog-api-key": key },
    {
      systemInstruction: { parts: [{ text: SYSTEM }] },
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: { maxOutputTokens: 16000 },
    },
    "Gemini"
  );
  const parts = d?.candidates?.[0]?.content?.parts;
  if (!parts) throw new Error("Gemini: الرد فارغ");
  return parts.map((p: any) => p.text || "").join("");
}

function extract(text: string): string {
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

export async function generateApp(
  description: string,
  existingHtml: string | null,
  onStatus: (s: string) => void
): Promise<{ html: string; provider: string }> {
  const prompt = existingHtml
    ? `Here is the current app:\n\`\`\`html\n${existingHtml}\n\`\`\`\n\nApply this change and return the FULL updated file:\n${description}`
    : `Create this app:\n${description}`;

  const claudeKey = await SecureStore.getItemAsync("CLAUDE_API_KEY");
  const geminiKey = await SecureStore.getItemAsync("GEMINI_API_KEY");

  const providers = [
    { label: "Claude", key: claudeKey, call: (k: string) => callClaude(k, prompt), tries: 2 },
    { label: "Gemini", key: geminiKey, call: (k: string) => callGemini(k, prompt), tries: 3 },
  ];

  const failures: string[] = [];
  for (const p of providers) {
    if (!p.key) {
      failures.push(`${p.label}: المفتاح غير محفوظ في تبويب المفاتيح`);
      continue;
    }
    for (let i = 1; i <= p.tries; i++) {
      onStatus(`⏳ بيتولّد الكود بواسطة ${p.label}${i > 1 ? ` (محاولة ${i})` : ""}...`);
      try {
        const html = extract(await p.call(p.key));
        return { html, provider: p.label };
      } catch (e: any) {
        const msg = String(e?.message || e).slice(0, 200);
        const retryable = e?.status === undefined || [0, 500, 502, 503, 529].includes(e.status);
        if (!retryable || i === p.tries) {
          failures.push(msg);
          break;
        }
        await sleep(8000 * i);
      }
    }
  }
  throw new Error(failures.join("\n"));
                  }
