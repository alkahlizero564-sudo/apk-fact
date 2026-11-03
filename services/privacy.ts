// Privacy of the clients' apps: apk-fact (code, descriptions, build logs) becomes a private repo, and a small
// public repo (apk-fact-updates) keeps only what installed apps need: the APK/AAB files and version.json.
// Build workflows publish there through the UPDATES_REPO variable and the UPDATES_TOKEN secret
// (scripts/updates_repo.py).
import { githubApi, githubToken, getFileText, listDir } from "./github";
import { REPO } from "./config";
import { checkGithub as check, setRepoSecret, setRepoVariable } from "./repoSecrets";
import type { Report } from "./appActions";

export const UPDATES_NAME = "apk-fact-updates";

export type PrivacyStatus = { repoPrivate: boolean; updatesRepo: string | null; updatesReady: boolean };

let cachedFilesRepo: string | null = null;

/** Where the built APK/AAB files are published: the updates repo once it is set up, else apk-fact. */
export async function filesRepo(): Promise<string> {
  if (cachedFilesRepo) return cachedFilesRepo;
  try {
    const res = await githubApi(`/repos/${REPO}/actions/variables/UPDATES_REPO`);
    if (res.ok) {
      const v = String((await res.json()).value ?? "").trim();
      if (v) return (cachedFilesRepo = v);
    }
  } catch {}
  return REPO;
}

export async function privacyStatus(): Promise<PrivacyStatus> {
  const repo = await (await check(await githubApi(`/repos/${REPO}`), "قراءة المستودع")).json();
  const v = await githubApi(`/repos/${REPO}/actions/variables/UPDATES_REPO`);
  const updatesRepo = v.ok ? String((await v.json()).value ?? "") || null : null;
  const updatesReady = !!updatesRepo && (await githubApi(`/repos/${updatesRepo}`)).ok;
  return { repoPrivate: !!repo.private, updatesRepo, updatesReady };
}

// Steps: repo -> secret -> variable
export async function setupUpdatesRepo(report: Report): Promise<string> {
  report("repo", "active");
  const me = await (await check(await githubApi("/user"), "قراءة حساب GitHub")).json();
  const repo = `${me.login}/${UPDATES_NAME}`;
  const found = await githubApi(`/repos/${repo}`);
  if (found.ok) {
    if ((await found.json()).private) throw new Error(`المستودع ${repo} موجود لكنه خاص. التطبيقات المثبّتة لازم تقدر تقراه، فخلّيه عام.`);
    report("repo", "done", `${repo} (موجود)`);
  } else {
    await check(
      await githubApi("/user/repos", {
        method: "POST",
        body: {
          name: UPDATES_NAME,
          private: false,
          auto_init: true,
          description: "APK Fact: update files of the apps (APK/AAB and version.json only, no source code)",
        },
      }),
      "إنشاء مستودع التحديثات"
    );
    report("repo", "done", `${repo} (عام، بدون كود)`);
  }

  report("secret", "active");
  await setRepoSecret("UPDATES_TOKEN", await githubToken());
  report("secret", "done", "UPDATES_TOKEN مشفّر في أسرار المستودع");

  report("variable", "active");
  await setRepoVariable("UPDATES_REPO", repo);
  cachedFilesRepo = repo;
  report("variable", "done", "كل بناء جاي بينشر ملفاته وتحديثاته هناك");
  return repo;
}

/** Apps that have installed copies (a published version.json): they need one new build after the switch. */
export async function appsWithInstalls(): Promise<string[]> {
  const names = await listDir(REPO, "apps");
  const out: string[] = [];
  for (const n of names) {
    try {
      if (await getFileText(REPO, `apps/${n}/version.json`)) out.push(n);
    } catch {}
  }
  return out;
}

export async function makeRepoPrivate() {
  const res = await githubApi(`/repos/${REPO}`, { method: "PATCH", body: { private: true } });
  if (res.status === 403 || res.status === 404) {
    throw new Error(
      "مفتاح GitHub ما عنده صلاحية تغيير المستودع. اعمل مفتاح جديد بصلاحية repo كاملة (أو Administration: write)، أو " +
        "خلّي المستودع خاص من GitHub: Settings > General > Danger Zone > Change visibility."
    );
  }
  await check(res, "تحويل المستودع لخاص");
}

/** GitHub's free build minutes per month for a private repo on a free personal account. */
export const FREE_MINUTES = 2000;
/** GitHub billing: payment method and the Actions budget (spending limit) that allows minutes beyond the free ones. */
export const BILLING_URL = "https://github.com/settings/billing";

/**
 * Build minutes this month (approximate: run start to finish; GitHub rounds each job up to a whole minute).
 * Only counts while apk-fact is private; public repos build for free.
 */
export async function monthMinutes(): Promise<number> {
  const now = new Date();
  const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)).toISOString().slice(0, 10);
  let total = 0;
  for (let page = 1; page <= 10; page++) {
    const res = await githubApi(`/repos/${REPO}/actions/runs?per_page=100&page=${page}&created=%3E%3D${start}`);
    if (!res.ok) break;
    const runs = ((await res.json()).workflow_runs ?? []) as any[];
    for (const r of runs) {
      if (r.status !== "completed" || !r.run_started_at) continue;
      const ms = new Date(r.updated_at).getTime() - new Date(r.run_started_at).getTime();
      total += Math.max(1, Math.ceil(ms / 60000));
    }
    if (runs.length < 100) break;
  }
  return total;
}
