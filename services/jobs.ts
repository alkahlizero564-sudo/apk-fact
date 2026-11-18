// Background jobs: everything APK Fact starts on GitHub (create, edit, build, connected pair, live link) is recorded
// here, so it is still followed after the owner leaves the app or Android stops it. When a job ends, the owner gets
// a notification (when they are not looking at the app). Two watchers finish jobs:
//  - the screen that started it, while APK Fact is alive (its own polling loop calls finishJob);
//  - a background task (services/backgroundJobs.ts) that Android runs every ~15 minutes, even with the app closed,
//    and that checkJobs() also runs whenever the app comes back to the foreground.
// A job is removed by whichever watcher sees it end first, so the owner is notified once.
import AsyncStorage from "@react-native-async-storage/async-storage";
import { AppState } from "react-native";
import * as Notifications from "expo-notifications";
import { REPO } from "./config";
import { getWorkflowRun, listWorkflowRuns } from "./github";

export type Job = {
  id: string;
  title: string; // what the owner sees: "إنشاء taregba (زبون + إدارة)"
  workflow: string; // e.g. "generate-pair.yml"
  prevId: number; // the newest run before this job started; the job's run is the first newer one
  match?: string; // the run's title when several jobs share a workflow (builds: "Build <app>")
  runId?: number; // filled once the run is known
  startedAt: number;
};

const KEY = "apkfact-jobs";
const MAX_AGE = 3 * 60 * 60 * 1000; // a run that is not over after 3 hours is dropped (GitHub stops jobs at 6 h; ours ~1 h)

async function load(): Promise<Job[]> {
  try {
    return JSON.parse((await AsyncStorage.getItem(KEY)) || "[]");
  } catch {
    return [];
  }
}

async function save(jobs: Job[]) {
  await AsyncStorage.setItem(KEY, JSON.stringify(jobs)).catch(() => {});
}

export async function pendingJobs(): Promise<Job[]> {
  return load();
}

// Show notifications even when a notification arrives while the app is open (we only send one when it is not
// in front, but the background task can fire at any moment).
Notifications.setNotificationHandler({
  handleNotification: async () => ({ shouldShowAlert: true, shouldPlaySound: true, shouldSetBadge: false }),
});

let channelReady = false;
async function ensureNotifications(): Promise<boolean> {
  try {
    if (!channelReady) {
      await Notifications.setNotificationChannelAsync("jobs", {
        name: "متابعة الإنشاء والبناء",
        importance: Notifications.AndroidImportance.HIGH,
        vibrationPattern: [0, 200, 120, 200],
      });
      channelReady = true;
    }
    const cur = await Notifications.getPermissionsAsync();
    if (cur.granted) return true;
    if (!cur.canAskAgain) return false;
    return (await Notifications.requestPermissionsAsync()).granted;
  } catch {
    return false;
  }
}

/** Records a job that is now running on GitHub (and asks for the notification permission the first time). */
export async function addJob(j: Omit<Job, "id" | "startedAt"> & { id?: string }): Promise<string> {
  const job: Job = { ...j, id: j.id ?? `${j.workflow}:${j.prevId}:${j.match ?? ""}:${Date.now()}`, startedAt: Date.now() };
  const jobs = (await load()).filter((x) => x.id !== job.id);
  jobs.push(job);
  await save(jobs);
  ensureNotifications();
  // Imported lazily: backgroundJobs imports this module (the task body calls checkJobs).
  require("./backgroundJobs").startBackgroundWatch();
  return job.id;
}

export async function setJobRun(id: string, runId: number) {
  const jobs = await load();
  const j = jobs.find((x) => x.id === id);
  if (j && j.runId !== runId) {
    j.runId = runId;
    await save(jobs);
  }
}

/**
 * Marks a job as over and tells the owner. Returns false when another watcher already finished it.
 * `alwaysNotify`: notify even when the app is in front (the background task uses it; it doesn't know what is shown).
 */
export async function finishJob(id: string, ok: boolean, alwaysNotify = false): Promise<boolean> {
  const jobs = await load();
  const j = jobs.find((x) => x.id === id);
  if (!j) return false;
  await save(jobs.filter((x) => x.id !== id));
  if ((alwaysNotify || AppState.currentState !== "active") && (await ensureNotifications())) {
    await Notifications.scheduleNotificationAsync({
      content: {
        title: ok ? `✅ جاهز: ${j.title}` : `❌ لم يكتمل: ${j.title}`,
        body: ok ? "افتح APK Fact للمتابعة." : "افتح APK Fact لترى السبب وتعيد المحاولة.",
        data: { job: j.id },
      },
      trigger: { channelId: "jobs" } as any,
    }).catch(() => {});
  }
  if (!(await load()).length) require("./backgroundJobs").stopBackgroundWatch();
  return true;
}

/** Looks every pending job up on GitHub and finishes the ones that ended. Returns how many ended. */
export async function checkJobs(fromBackground = false): Promise<number> {
  const jobs = await load();
  let ended = 0;
  for (const j of jobs) {
    try {
      let run = j.runId ? await getWorkflowRun(REPO, j.runId) : null;
      if (!run && !j.runId) {
        const runs = await listWorkflowRuns(REPO, j.workflow, 20);
        const found = runs
          .filter((r: any) => r.id > j.prevId && (!j.match || r.title === j.match))
          .sort((a: any, b: any) => a.id - b.id)[0];
        if (found) {
          await setJobRun(j.id, found.id);
          run = found;
        }
      }
      if (run && run.status === "completed") {
        if (await finishJob(j.id, run.conclusion === "success", fromBackground)) ended++;
      } else if (Date.now() - j.startedAt > MAX_AGE) {
        await save((await load()).filter((x) => x.id !== j.id));
      }
    } catch {
      // offline or GitHub busy: try again next time
    }
  }
  return ended;
}
