// Two connected apps (customer + admin) on one Supabase backend, with email-code login and push.
// The phone syncs the needed keys to GitHub secrets, starts generate-pair.yml and follows its steps.
import * as SecureStore from "expo-secure-store";
import { githubApi, latestRunId, listWorkflowRuns, getFailureLog, triggerWorkflow, getFileText } from "./github";
import { REPO } from "./config";
import { runSql } from "./supabase";
import { listProjects, secretName, tokenFor } from "./projects";
import { setRepoSecret, setRepoVariable } from "./repoSecrets";
import type { Lang } from "./langs";
import type { Report } from "./appActions";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export type PairOptions = {
  base: string;
  lang: Lang;
  admins: string;
  push: boolean;
  description: string;
  customerName?: string;
  adminName?: string;
  /** A client's / created project (services/projects.ts); empty = the default project from Settings. */
  supabaseRef?: string;
};

export function pairApps(base: string) {
  return { customer: `${base}-customer`, admin: `${base}-admin` };
}

export type PairReadiness = { supabase: boolean; firebase: boolean; firebaseProject?: string; smtp: boolean };

export async function pairReadiness(): Promise<PairReadiness> {
  const get = (k: string) => SecureStore.getItemAsync(k);
  const supabase =
    (!!(await get("SUPABASE_ACCESS_TOKEN")) && !!(await get("SUPABASE_PROJECT_REF"))) || (await listProjects()).length > 0;
  let firebaseProject: string | undefined;
  try {
    firebaseProject = JSON.parse((await get("FIREBASE_SERVICE_ACCOUNT")) ?? "").project_id;
  } catch {}
  return { supabase, firebase: !!firebaseProject, firebaseProject, smtp: !!(await get("SMTP_HOST")) };
}

/** Validates a pasted Firebase service account JSON and returns its project id. */
export function parseServiceAccount(raw: string): string {
  let sa: any;
  try {
    sa = JSON.parse(raw);
  } catch {
    throw new Error("هذا ليس ملف JSON صالح. انسخ محتوى ملف مفتاح حساب الخدمة كامل.");
  }
  if (!sa.project_id || !sa.client_email || !String(sa.private_key ?? "").includes("PRIVATE KEY")) {
    throw new Error("الملف ناقص: لازم يحتوي project_id و client_email و private_key (من Firebase > إعدادات المشروع > حسابات الخدمة).");
  }
  return sa.project_id;
}

async function syncSecrets(push: boolean, supabaseRef?: string) {
  const get = async (k: string) => ((await SecureStore.getItemAsync(k)) ?? "").trim();
  if (supabaseRef) {
    // A client's / created project: its own token, as the secret generate-pair.yml reads for this ref.
    await setRepoSecret(secretName(supabaseRef), await tokenFor(supabaseRef));
  } else {
    const token = await get("SUPABASE_ACCESS_TOKEN");
    const ref = await get("SUPABASE_PROJECT_REF");
    if (!token || !ref) throw new Error("أكمل إعداد Supabase من الإعدادات (المفتاح و Project Ref)، أو اختار مشروع زبون.");
    await setRepoSecret("SUPABASE_ACCESS_TOKEN", token);
    await setRepoVariable("SUPABASE_PROJECT_REF", ref);
  }
  const publishable = supabaseRef ? "" : await get("SUPABASE_PUBLISHABLE_KEY");
  if (publishable) {
    if (/^sb_secret_/.test(publishable) || /service_role/.test(publishable)) {
      throw new Error("المفتاح ده سرّي (secret). حط المفتاح العام publishable أو anon، مش السري.");
    }
    await setRepoSecret("SUPABASE_PUBLISHABLE_KEY", publishable);
  }
  const host = await get("SMTP_HOST");
  if (host) {
    await setRepoSecret(
      "SUPABASE_SMTP",
      JSON.stringify({
        host,
        port: (await get("SMTP_PORT")) || "587",
        user: await get("SMTP_USER"),
        pass: await get("SMTP_PASS"),
        from: (await get("SMTP_FROM")) || (await get("SMTP_USER")),
        name: "APK Fact",
      })
    );
  }
  if (push) {
    const sa = await get("FIREBASE_SERVICE_ACCOUNT");
    if (!sa) throw new Error("للإشعارات: أضف مفتاح حساب خدمة Firebase من الإعدادات.");
    parseServiceAccount(sa);
    await setRepoSecret("FIREBASE_SERVICE_ACCOUNT", sa);
  }
  // The pair is generated on GitHub, so the AI keys must be repo secrets too — Settings only keeps them on the
  // phone (for the instant preview). Push every key the user entered, so all of them are available to the build
  // (more keys = far fewer failures when a model is busy/rate-limited). Without this, only a manually-set key works.
  const geminiKeys = (
    await Promise.all(["GEMINI_API_KEY", "GEMINI_API_KEY_2", "GEMINI_API_KEY_3"].map((k) => get(k)))
  ).filter(Boolean);
  if (!geminiKeys.length) throw new Error("أضف مفتاح Gemini واحداً على الأقل من الإعدادات.");
  await Promise.all([
    setRepoSecret("GEMINI_API_KEY", geminiKeys[0]),
    geminiKeys[1] ? setRepoSecret("GEMINI_API_KEY_2", geminiKeys[1]) : Promise.resolve(),
    geminiKeys[2] ? setRepoSecret("GEMINI_API_KEY_3", geminiKeys[2]) : Promise.resolve(),
  ]);
  const claude = await get("CLAUDE_API_KEY");
  if (claude) await setRepoSecret("CLAUDE_API_KEY", claude);
  const model = await get("GEMINI_MODEL");
  if (model) await setRepoVariable("GEMINI_MODEL", model);
}

// Workflow step name -> timeline step key.
const STEP_KEYS: Record<string, string> = {
  "Supabase: tables and roles": "backend",
  "Supabase: email code login": "auth",
  "Supabase: sign-in (and its self-test)": "auth",
  "Firebase: notifications": "firebase",
  "Generate customer app": "customer",
  "Generate admin app": "admin",
  Save: "save",
};

// Steps: sync -> backend -> auth -> firebase -> customer -> admin -> save
export async function createPair(o: PairOptions, report: Report) {
  report("sync", "active");
  await syncSecrets(o.push, o.supabaseRef);
  const prevId = await latestRunId(REPO, "generate-pair.yml");
  await triggerWorkflow(REPO, "generate-pair.yml", {
    base: o.base,
    lang: o.lang,
    admins: o.admins,
    push: o.push ? "true" : "false",
    description: o.description,
    names: [o.customerName, o.adminName].map((n) => (n ?? "").replace(/[|]/g, "").trim()).join("|"),
    ...(o.supabaseRef ? { supabase_ref: o.supabaseRef } : {}),
  });
  report("sync", "done");

  const started = Date.now();
  let runId = 0;
  while (Date.now() - started < 60 * 60 * 1000) {
    await sleep(6000);
    if (!runId) {
      runId = (await listWorkflowRuns(REPO, "generate-pair.yml")).find((r: any) => r.id > prevId)?.id ?? 0;
      continue;
    }
    const jobs = (await (await githubApi(`/repos/${REPO}/actions/runs/${runId}/jobs`)).json()).jobs ?? [];
    const job = jobs[0];
    if (!job) continue;
    for (const st of job.steps ?? []) {
      const key = STEP_KEYS[st.name];
      if (!key) continue;
      if (st.status === "in_progress") report(key, "active");
      else if (st.status === "completed")
        report(key, st.conclusion === "success" ? "done" : st.conclusion === "skipped" ? "done" : "error");
    }
    if (job.status === "completed") {
      if (job.conclusion === "success") return pairApps(o.base);
      const tail = await getFailureLog(REPO, runId);
      throw new Error("فشل إنشاء التطبيقين." + (tail ? "\n" + tail : ""));
    }
  }
  throw new Error("أخذ وقت طويل. شوف تطبيقاتي بعد شوية.");
}

// ---- Admin accounts of a pair (changed live in Supabase; no rebuild needed) ----

export type AdminAccount = { email: string; signedUp: boolean };

const EMAIL_RE = /^[^\s@'"\\;]+@[^\s@'"\\;]+\.[^\s@'"\\;]+$/;

function safePrefix(prefix: string) {
  if (!/^[a-z][a-z0-9_]{0,40}$/.test(prefix)) throw new Error("بيانات الربط ناقصة في هذا المشروع.");
  return prefix;
}

function sqlEmail(email: string) {
  const e = email.trim().toLowerCase();
  if (!EMAIL_RE.test(e)) throw new Error("اكتب بريد إلكتروني صحيح.");
  return `'${e}'`;
}

export async function listAdmins(prefix: string, ref: string): Promise<AdminAccount[]> {
  const p = safePrefix(prefix);
  const rows = await runSql(
    `select a.email, exists (select 1 from public.${p}_profiles pr where lower(pr.email) = lower(a.email)) as signed_up ` +
      `from public.${p}_admins a order by a.email;`,
    ref
  );
  return (Array.isArray(rows) ? rows : []).map((r: any) => ({ email: r.email, signedUp: !!r.signed_up }));
}

export async function addAdmin(prefix: string, ref: string, email: string) {
  const p = safePrefix(prefix);
  const e = sqlEmail(email);
  await runSql(
    `insert into public.${p}_admins(email) values (${e}) on conflict do nothing; ` +
      `update public.${p}_profiles set role = 'admin' where lower(email) = ${e};`,
    ref
  );
}

export async function removeAdmin(prefix: string, ref: string, email: string) {
  const p = safePrefix(prefix);
  const e = sqlEmail(email);
  const left = await listAdmins(prefix, ref);
  if (left.filter((a) => a.email.toLowerCase() !== email.trim().toLowerCase()).length === 0) {
    throw new Error("لازم يفضل حساب إدارة واحد على الأقل.");
  }
  await runSql(
    `delete from public.${p}_admins where lower(email) = ${e}; ` +
      `update public.${p}_profiles set role = 'customer' where lower(email) = ${e};`,
    ref
  );
}

async function installAdminSql(p: string, ref: string) {
  const template = await getFileText(REPO, "scripts/templates/admin_pin.sql");
  if (!template) throw new Error("ملف صلاحيات الإدارة مش موجود في المستودع.");
  await runSql(template.split("{p}").join(p), ref);
}

/** Sets the secret admin PIN of a pair (installs the admin functions first; the SQL lives in the repo). */
export async function setAdminPin(prefix: string, ref: string, pin: string) {
  const p = safePrefix(prefix);
  if (!/^[A-Za-z0-9]{4,12}$/.test(pin)) throw new Error("رمز الإدارة: من 4 إلى 12 حرف إنجليزي أو رقم.");
  await installAdminSql(p, ref);
  await runSql(
    `insert into public.${p}_admin_secret (id, pin_hash) values (1, extensions.crypt('${pin}', extensions.gen_salt('bf'))) ` +
      `on conflict (id) do update set pin_hash = excluded.pin_hash, updated_at = now();`,
    ref
  );
}

/** Open mode: everyone who signs in through the admin app becomes an admin (no PIN). */
export async function openAdminMode(prefix: string, ref: string) {
  const p = safePrefix(prefix);
  await installAdminSql(p, ref);
  await runSql(`delete from public.${p}_admin_secret;`, ref);
}

export type AdminMode = "missing" | "open" | "pin";

export async function adminMode(prefix: string, ref: string): Promise<AdminMode> {
  const p = safePrefix(prefix);
  const rows = await runSql(
    `select to_regprocedure('public.${p}_claim_admin(text)') is not null as installed, ` +
      `(to_regclass('public.${p}_admin_secret') is not null) as has_table;`,
    ref
  );
  const r = Array.isArray(rows) ? rows[0] : null;
  if (!r?.installed) return "missing";
  if (!r.has_table) return "open";
  const n = await runSql(`select count(*)::int as n from public.${p}_admin_secret;`, ref);
  return Array.isArray(n) && n[0]?.n > 0 ? "pin" : "open";
}

export async function hasAdminPin(prefix: string, ref: string): Promise<boolean> {
  const p = safePrefix(prefix);
  try {
    const rows = await runSql(`select count(*)::int as n from public.${p}_admin_secret;`, ref);
    return Array.isArray(rows) && rows[0]?.n > 0;
  } catch {
    return false;
  }
}
