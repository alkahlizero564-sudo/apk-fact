// Two connected apps (customer + admin) on one Supabase backend, with email-code login and push.
// The phone syncs the needed keys to GitHub secrets, starts generate-pair.yml and follows its steps.
import * as SecureStore from "expo-secure-store";
import { githubApi, latestRunId, listWorkflowRuns, getFailureLog, triggerWorkflow } from "./github";
import { REPO } from "./config";
import { setRepoSecret, setRepoVariable } from "./repoSecrets";
import type { Lang } from "./langs";
import type { Report } from "./appActions";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export type PairOptions = { base: string; lang: Lang; admins: string; push: boolean; description: string };

export function pairApps(base: string) {
  return { customer: `${base}-customer`, admin: `${base}-admin` };
}

export type PairReadiness = { supabase: boolean; firebase: boolean; firebaseProject?: string; smtp: boolean };

export async function pairReadiness(): Promise<PairReadiness> {
  const get = (k: string) => SecureStore.getItemAsync(k);
  const supabase = !!(await get("SUPABASE_ACCESS_TOKEN")) && !!(await get("SUPABASE_PROJECT_REF"));
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

async function syncSecrets(push: boolean) {
  const get = async (k: string) => ((await SecureStore.getItemAsync(k)) ?? "").trim();
  const token = await get("SUPABASE_ACCESS_TOKEN");
  const ref = await get("SUPABASE_PROJECT_REF");
  if (!token || !ref) throw new Error("أكمل إعداد Supabase من الإعدادات (المفتاح و Project Ref).");
  await setRepoSecret("SUPABASE_ACCESS_TOKEN", token);
  await setRepoVariable("SUPABASE_PROJECT_REF", ref);
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
}

// Workflow step name -> timeline step key.
const STEP_KEYS: Record<string, string> = {
  "Supabase: tables and roles": "backend",
  "Supabase: email code login": "auth",
  "Firebase: notifications": "firebase",
  "Generate customer app": "customer",
  "Generate admin app": "admin",
  Save: "save",
};

// Steps: sync -> backend -> auth -> firebase -> customer -> admin -> save
export async function createPair(o: PairOptions, report: Report) {
  report("sync", "active");
  await syncSecrets(o.push);
  const prevId = await latestRunId(REPO, "generate-pair.yml");
  await triggerWorkflow(REPO, "generate-pair.yml", {
    base: o.base,
    lang: o.lang,
    admins: o.admins,
    push: o.push ? "true" : "false",
    description: o.description,
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
