import * as SecureStore from "expo-secure-store";

export type GeneratedFile = { path: string; content: string };
export type GenerationResult = {
  files: GeneratedFile[];
  sql: string | null;
  summary: string;
};

// نماذج Gemini مرتبة: الأساسي ثم الاحتياطي
const GEMINI_MODELS = [
  "gemini-3.8-flash",
  "gemini-3.5-flash",
  "gemini-3-flash-preview",
];
const CLAUDE_MODEL = "claude-sonnet-4-6";
const MAX_ATTEMPTS = 2;
const RETRY_STATUSES = [429, 500, 502, 503, 504, 529];

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

const SYSTEM_PROMPT = `You are a code generator. Given a description of an app or website, respond with ONLY valid JSON (no markdown fences, no prose) in this exact shape:
{
  "summary": "one-line description of what you built",
  "files": [{"path": "relative/path.ext", "content": "full file content"}],
  "sql": "CREATE TABLE ... (or null if no database needed)"
}
IMPORTANT: Regardless of whether this is described as a "website" or a "mobile app", always build it as a SINGLE self-contained index.html file using plain HTML/CSS/JavaScript only (no build step, no external framework files, no React Native). This file must be fully functional and renderable directly inside a mobile WebView — real working buttons, navigation, forms, local state, etc. For a "mobile app" request specifically, style it to look and behave like a native mobile app: full-screen layout, bottom tab bar or similar mobile navigation, large touch targets, smooth transitions via CSS — but it is still implemented as HTML/CSS/JS so it can actually run live, not just be displayed as source code. If Supabase is needed, call it directly from JavaScript using fetch() against the Supabase REST API (the anon key and project URL will be provided by the person separately — leave clearly marked placeholders like SUPABASE_URL and SUPABASE_ANON_KEY as JS constants at the top of the file for them to fill in).`;

const EDIT_SYSTEM_PROMPT = `You are a code editor. You will be given the current files of an app or website, plus an instruction describing a change to make. Respond with ONLY valid JSON (no markdown fences, no prose) in this exact shape:
{
  "summary": "one-line description of what you changed",
  "files": [{"path": "relative/path.ext", "content": "full NEW file content"}],
  "sql": "any additional SQL to run (or null)"
}
Return the FULL content of every file that changed (not a diff). Files that didn't need to change can be omitted. Keep the project as plain HTML/CSS/JavaScript only (no React Native, no build step) so it keeps running live inside a mobile WebView exactly as before — just apply the requested change.`;

function extractJson(text: string): string {
  const fenceMatch = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  return fenceMatch ? fenceMatch[1].trim() : text.trim();
}

function parseResult(text: string): GenerationResult {
  try {
    return JSON.parse(extractJson(text));
  } catch {
    throw new Error("النموذج رجّع رد مش بالصيغة المتوقعة. جرب تاني أو بصياغة مختلفة.");
  }
}

// ---------- Gemini: يجرب كل النماذج بالترتيب ----------
async function runGemini(systemPrompt: string, prompt: string, apiKey: string): Promise<string> {
  const errors: string[] = [];

  for (const model of GEMINI_MODELS) {
    for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
      let res: Response;
      try {
        res = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-goog-api-key": apiKey,
            },
            body: JSON.stringify({
              systemInstruction: { parts: [{ text: systemPrompt }] },
              contents: [{ parts: [{ text: prompt }] }],
              generationConfig: { responseMimeType: "application/json" },
            }),
          }
        );
      } catch {
        errors.push(`${model}: network error`);
        if (attempt < MAX_ATTEMPTS) await sleep(2000);
        continue;
      }

      if (res.ok) {
        const data = await res.json();
        const text = (data.candidates?.[0]?.content?.parts ?? [])
          .map((p: any) => p.text ?? "")
          .join("");
        if (text) return text;
        errors.push(`${model}: empty response`);
        break;
      }

      const errText = await res.text();

      // النموذج غير موجود أو متوقف: انتقل للتالي
      if (
        res.status === 404 ||
        /no longer available|not found|is not supported/i.test(errText)
      ) {
        errors.push(`${model}: unavailable`);
        break;
      }

      // ضغط أو خطأ مؤقت: انتظر وأعد المحاولة
      if (RETRY_STATUSES.includes(res.status)) {
        errors.push(`${model}: ${res.status} (attempt ${attempt})`);
        if (attempt < MAX_ATTEMPTS) await sleep(2000 * 2 ** (attempt - 1));
        continue;
      }

      // خطأ حقيقي (مفتاح خاطئ مثلا): وقف
      throw new Error(`Gemini generation failed (${res.status}): ${errText}`);
    }
  }

  throw new Error(`Gemini failed, all models tried:\n${errors.join("\n")}`);
}

// ---------- Claude ----------
async function runClaude(systemPrompt: string, prompt: string, apiKey: string): Promise<string> {
  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: CLAUDE_MODEL,
        max_tokens: 8000,
        system: systemPrompt,
        messages: [{ role: "user", content: prompt }],
      }),
    });

    if (res.ok) {
      const data = await res.json();
      return data.content?.[0]?.text ?? "";
    }

    if (RETRY_STATUSES.includes(res.status) && attempt < MAX_ATTEMPTS) {
      await sleep(2000);
      continue;
    }
    throw new Error(`Claude generation failed (${res.status}): ${await res.text()}`);
  }
  throw new Error("Claude generation failed");
}

// ---------- يجرب المزود المختار ثم الآخر تلقائيا ----------
async function callAI(
  provider: "claude" | "gemini",
  systemPrompt: string,
  prompt: string
): Promise<string> {
  const order: ("claude" | "gemini")[] =
    provider === "gemini" ? ["gemini", "claude"] : ["claude", "gemini"];
  const errors: string[] = [];

  for (const p of order) {
    const keyName = p === "gemini" ? "GEMINI_API_KEY" : "CLAUDE_API_KEY";
    const apiKey = await SecureStore.getItemAsync(keyName);
    if (!apiKey) {
      errors.push(`${p}: ${keyName} missing`);
      continue;
    }
    try {
      return p === "gemini"
        ? await runGemini(systemPrompt, prompt, apiKey)
        : await runClaude(systemPrompt, prompt, apiKey);
    } catch (e: any) {
      errors.push(`${p}: ${e.message}`);
    }
  }

  throw new Error(errors.join("\n\n"));
}

// ---------- الدوال المصدّرة (نفس الأسماء القديمة) ----------
function mergeEdit(currentFiles: GeneratedFile[], parsed: GenerationResult): GenerationResult {
  const merged = [...currentFiles];
  for (const updated of parsed.files) {
    const idx = merged.findIndex((f) => f.path === updated.path);
    if (idx >= 0) merged[idx] = updated;
    else merged.push(updated);
  }
  return { files: merged, sql: parsed.sql ?? null, summary: parsed.summary };
}

export async function editCode(
  currentFiles: GeneratedFile[],
  instruction: string,
  provider: "claude" | "gemini"
): Promise<GenerationResult> {
  const filesBlock = currentFiles
    .map((f) => `--- ${f.path} ---\n${f.content}`)
    .join("\n\n");
  const prompt = `Current files:\n\n${filesBlock}\n\nInstruction: ${instruction}`;

  const text = await callAI(provider, EDIT_SYSTEM_PROMPT, prompt);
  return mergeEdit(currentFiles, parseResult(text));
}

export async function generateCode(
  description: string,
  kind: "app" | "website",
  provider: "claude" | "gemini"
): Promise<GenerationResult> {
  const prompt = `Build this ${kind === "app" ? "mobile app" : "website"}: ${description}`;
  const text = await callAI(provider, SYSTEM_PROMPT, prompt);
  const result = parseResult(text);

  if (!result.files || !Array.isArray(result.files)) {
    throw new Error("النموذج رجّع رد مش بالصيغة المتوقعة. جرب تاني أو بصياغة مختلفة.");
  }
  return result;
}
