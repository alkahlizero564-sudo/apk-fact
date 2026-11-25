// Every Gemini model the owner's keys can use, not only a fixed three. When a model's daily quota is used up on a
// key, that key+model pair is skipped for the rest of the day and the next model takes over, then the next, until
// one answers. Same ranking as scripts/gemini_client.py: pro > flash > flash-lite, newer first, stable before preview.
import AsyncStorage from "@react-native-async-storage/async-storage";

const SKIP = /(embedding|tts|image|imagen|live|audio|native|robotics|computer-use|aqa|veo|learnlm|gemma)/i;
const CACHE = "apkfact-gemini-models";
const DEAD = "apkfact-gemini-dead";

const today = () => new Date().toISOString().slice(0, 10);

function rank(name: string): number[] {
  const n = name.toLowerCase();
  const tier = n.includes("lite") ? 1 : n.includes("flash") ? 2 : n.includes("pro") ? 3 : 0;
  const v = parseFloat((n.match(/gemini-(\d+(?:\.\d+)?)/) || [])[1] || "0");
  const stable = /preview|exp/.test(n) ? 0 : 1;
  return [tier, v, stable];
}

export function byStrength(a: string, b: string): number {
  const x = rank(a);
  const y = rank(b);
  for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return y[i] - x[i];
  return a.localeCompare(b);
}

let memo: { day: string; models: string[] } | null = null;

/** Text models the keys can call, strongest first (asked from Google once a day). [] when it cannot be asked. */
export async function availableModels(keys: string[]): Promise<string[]> {
  if (memo && memo.day === today()) return memo.models;
  try {
    const saved = JSON.parse((await AsyncStorage.getItem(CACHE)) || "null");
    if (saved?.day === today() && saved.models?.length) return (memo = saved).models;
  } catch {}
  const found = new Set<string>();
  for (const key of keys) {
    try {
      let token = "";
      for (let page = 0; page < 10; page++) {
        const res = await fetch(
          "https://generativelanguage.googleapis.com/v1beta/models?pageSize=1000" + (token ? `&pageToken=${token}` : ""),
          { headers: { "x-goog-api-key": key } }
        );
        if (!res.ok) break;
        const data = await res.json();
        for (const m of data.models || []) {
          const name = String(m.name || "").replace(/^models\//, "");
          if (name.startsWith("gemini-") && (m.supportedGenerationMethods || []).includes("generateContent") && !SKIP.test(name)) {
            found.add(name);
          }
        }
        token = data.nextPageToken || "";
        if (!token) break;
      }
    } catch {
      continue;
    }
    if (found.size) break;
  }
  const models = [...found].sort(byStrength);
  if (models.length) {
    memo = { day: today(), models };
    AsyncStorage.setItem(CACHE, JSON.stringify(memo)).catch(() => {});
  }
  return models;
}

/** `first` (the chosen model and the step's own preferred ones) in that order, then every other model. */
export async function modelOrder(first: string[], keys: string[]): Promise<string[]> {
  const head = [...new Set(first.filter(Boolean))];
  const rest = (await availableModels(keys)).filter((m) => !head.includes(m));
  return [...head, ...rest];
}

// ---- key+model pairs out of today's quota ----

let dead: { day: string; pairs: string[] } | null = null;
const pairId = (key: string, model: string) => `${key.slice(-6)}|${model}`;

async function loadDead() {
  if (dead && dead.day === today()) return dead;
  try {
    const d = JSON.parse((await AsyncStorage.getItem(DEAD)) || "null");
    dead = d?.day === today() ? d : { day: today(), pairs: [] };
  } catch {
    dead = { day: today(), pairs: [] };
  }
  return dead!;
}

export async function isExhausted(key: string, model: string): Promise<boolean> {
  return (await loadDead()).pairs.includes(pairId(key, model));
}

/** Remembers a key+model pair whose daily quota is used up (429 'per day' / 'quota'); other errors are ignored. */
export async function noteFailure(key: string, model: string, status: number | undefined, message: string) {
  const m = (message || "").toLowerCase();
  if (status !== 429 && !m.includes("resource_exhausted")) return;
  if (!(m.includes("per day") || m.includes("perday") || m.includes("daily") || m.includes("quota"))) return;
  const d = await loadDead();
  const id = pairId(key, model);
  if (!d.pairs.includes(id)) {
    d.pairs.push(id);
    AsyncStorage.setItem(DEAD, JSON.stringify(d)).catch(() => {});
  }
}
