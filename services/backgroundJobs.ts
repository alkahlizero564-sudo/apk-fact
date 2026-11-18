// The background task that keeps following GitHub jobs while APK Fact is closed (Android runs it about every 15
// minutes; it survives the app being swiped away and a reboot). It must be defined at the top level of a module that
// the app imports at start-up (App.tsx imports this file), so Android can run it without opening a screen.
import * as TaskManager from "expo-task-manager";
import * as BackgroundFetch from "expo-background-fetch";
import { checkJobs, pendingJobs } from "./jobs";

export const JOBS_TASK = "apkfact-follow-jobs";

TaskManager.defineTask(JOBS_TASK, async () => {
  try {
    const ended = await checkJobs(true);
    if (!(await pendingJobs()).length) await stopBackgroundWatch();
    return ended ? BackgroundFetch.BackgroundFetchResult.NewData : BackgroundFetch.BackgroundFetchResult.NoData;
  } catch {
    return BackgroundFetch.BackgroundFetchResult.Failed;
  }
});

export async function startBackgroundWatch() {
  try {
    if (await TaskManager.isTaskRegisteredAsync(JOBS_TASK)) return;
    await BackgroundFetch.registerTaskAsync(JOBS_TASK, { minimumInterval: 15 * 60, stopOnTerminate: false, startOnBoot: true });
  } catch {
    // background fetch unavailable (restricted by the system): the in-app watcher and the resume check still work
  }
}

export async function stopBackgroundWatch() {
  try {
    if (await TaskManager.isTaskRegisteredAsync(JOBS_TASK)) await BackgroundFetch.unregisterTaskAsync(JOBS_TASK);
  } catch {
    // nothing to stop
  }
}
