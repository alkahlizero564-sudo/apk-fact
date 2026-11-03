// A Supabase database per client: besides the default project (Settings > Supabase), the owner keeps a list of
// projects: projects in a client's own Supabase account (project ref + that account's access token), and
// projects APK Fact creates in the owner's account. A connected pair is created in the project picked for it.
// Each project's access token is kept on the phone (SUPABASE_TOKEN_<ref>) and as the repo secret
// SUPABASE_TOKEN_<REF>, which generate-pair.yml reads when the pair is created in that project.
import * as SecureStore from "expo-secure-store";
import * as Crypto from "expo-crypto";
import { setRepoSecret } from "./repoSecrets";
import type { Report } from "./appActions";

const MGMT_API = "https://api.supabase.com/v1";
const LIST_KEY = "SUPABASE_PROJECTS";
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export type DbProject = { ref: string; label: string; kind: "client" | "created"; region?: string };

// Regions APK Fact offers when it creates a project (codes from the Supabase Management API).
export const REGIONS: { code: string; label: string }[] = [
  { code: "eu-central-1", label: "فرانكفورت (الأقرب للشرق الأوسط)" },
  { code: "ap-south-1", label: "مومباي" },
  { code: "eu-west-2", label: "لندن" },
  { code: "us-east-1", label: "أمريكا (شرق)" },
];

const tokenKey = (ref: string) => `SUPABASE_TOKEN_${ref}`;
export const secretName = (ref: string) => `SUPABASE_TOKEN_${ref.toUpperCase()}`;

export function validRef(ref: string) {
  return /^[a-z]{20}$/.test(ref);
}

export async function listProjects(): Promise<DbProject[]> {
  try {
    const list = JSON.parse((await SecureStore.getItemAsync(LIST_KEY)) ?? "[]");
    return Array.isArray(list) ? list.filter((p) => p && validRef(p.ref)) : [];
  } catch {
    return [];
  }
}

async function saveList(list: DbProject[]) {
  await SecureStore.setItemAsync(LIST_KEY, JSON.stringify(list));
}

/** The access token for a project: its own one when it was added, else the default account's. */
export async function tokenFor(ref?: string): Promise<string> {
  if (ref) {
    const own = await SecureStore.getItemAsync(tokenKey(ref));
    if (own) return own;
  }
  const token = await SecureStore.getItemAsync("SUPABASE_ACCESS_TOKEN");
  if (!token) {
    throw new Error(
      "SUPABASE_ACCESS_TOKEN missing. This is a Personal Access Token from supabase.com → Account → Access Tokens (different from the project's anon key)."
    );
  }
  return token;
}

async function api(token: string, path: string, init: { method?: string; body?: unknown } = {}) {
  const res = await fetch(MGMT_API + path, {
    method: init.method ?? "GET",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: init.body === undefined ? undefined : JSON.stringify(init.body),
  });
  const text = await res.text();
  if (!res.ok) {
    if (res.status === 401) throw new Error("مفتاح الوصول غير صحيح أو منتهي (Supabase → Account → Access Tokens).");
    if (res.status === 403 || res.status === 404) throw new Error("المشروع ده مش موجود أو المفتاح ما عنده صلاحية عليه.");
    throw new Error(`Supabase (${res.status}): ${text.slice(0, 300)}`);
  }
  return text.trim() ? JSON.parse(text) : null;
}

async function remember(p: DbProject, token: string) {
  await SecureStore.setItemAsync(tokenKey(p.ref), token);
  // generate-pair.yml reads it as secrets[format('SUPABASE_TOKEN_{0}', ref)].
  await setRepoSecret(secretName(p.ref), token);
  const list = (await listProjects()).filter((x) => x.ref !== p.ref);
  await saveList([...list, p]);
}

/** A project in the client's own Supabase account: checks the ref and the token, then saves them. */
export async function addClientProject(label: string, ref: string, token: string): Promise<DbProject> {
  ref = ref.trim().toLowerCase();
  token = token.trim();
  if (!validRef(ref)) throw new Error("رمز المشروع (Project Ref) 20 حرف إنجليزي صغير، من رابط المشروع: supabase.com/dashboard/project/<الرمز>");
  if (!/^sbp_/.test(token)) throw new Error("مفتاح الوصول يبدأ بـ sbp_ (من حساب الزبون: Account → Access Tokens)، مش مفتاح anon.");
  const info = await api(token, `/projects/${ref}`);
  const p: DbProject = { ref, label: label.trim() || info?.name || ref, kind: "client", region: info?.region };
  await remember(p, token);
  return p;
}

// Steps: org -> create -> ready
/** A new project in the owner's account (the default token). The free plan allows 2 active projects. */
export async function createProject(label: string, region: string, report: Report): Promise<DbProject> {
  const token = await tokenFor();
  report("org", "active");
  const orgs = (await api(token, "/organizations")) as { id: string; slug: string; name: string }[];
  if (!orgs?.length) throw new Error("حسابك في Supabase ما فيه منظمة (Organization). اعمل واحدة من supabase.com الأول.");
  const org = orgs[0];
  report("org", "done", org.name);

  report("create", "active");
  const name = (label.trim() || "apk-fact-client").replace(/[<>"'`\\]/g, "").slice(0, 60) || "apk-fact-client";
  // The database password is never needed by APK Fact (it uses the Management API); it only has to be strong.
  const chars = "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const dbPass = Array.from(Crypto.getRandomBytes(24), (b) => chars[b % chars.length]).join("");
  let created: any;
  try {
    created = await api(token, "/projects", {
      method: "POST",
      body: { name, organization_slug: org.slug || org.id, db_pass: dbPass, region },
    });
  } catch (e: any) {
    if (/limit|maximum|free.*project|projects.*free/i.test(e.message)) {
      throw new Error("وصلت لحد المشاريع المجانية في Supabase (مشروعين نشطين). أوقف مشروع قديم، أو رقّي الخطة، أو استخدم حساب الزبون.");
    }
    throw e;
  }
  const ref = created?.ref ?? created?.id;
  if (!validRef(String(ref))) throw new Error("Supabase ما رجّع رمز المشروع الجديد.");
  report("create", "done", ref);

  report("ready", "active");
  const started = Date.now();
  let ready = false;
  while (Date.now() - started < 8 * 60 * 1000) {
    await sleep(10000);
    const info = await api(token, `/projects/${ref}`).catch(() => null);
    if (info?.status === "INIT_FAILED") throw new Error("Supabase فشل في تجهيز المشروع الجديد. جرّب تاني بعد شوية.");
    if (info?.status === "ACTIVE_HEALTHY") {
      ready = true;
      break;
    }
  }
  if (!ready) throw new Error(`المشروع ${ref} لسه بيتجهّز في Supabase. استنى دقايق وأضفه من «مشروع في حساب زبون» بنفس الرمز.`);
  report("ready", "done", "المشروع جاهز");
  const p: DbProject = { ref, label: label.trim() || name, kind: "created", region };
  await remember(p, token);
  return p;
}

export async function removeProject(ref: string) {
  await saveList((await listProjects()).filter((x) => x.ref !== ref));
  await SecureStore.deleteItemAsync(tokenKey(ref)).catch(() => {});
}
