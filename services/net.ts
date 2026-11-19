// Network drops (switching towers, Wi-Fi ↔ 4G, a tunnel) used to fail a whole pair creation at the first request
// that hit the gap. netFetch waits for the network to come back and sends the request again instead.
// Only failures where no answer arrived at all are retried (fetch throws); an HTTP error status is a real answer.

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** How long a request keeps waiting for the network before giving up. */
const MAX_WAIT_MS = 3 * 60 * 1000;

type Listener = (waiting: boolean) => void;
const listeners = new Set<Listener>();
let waitingCount = 0;

function setWaiting(delta: number) {
  const before = waitingCount > 0;
  waitingCount = Math.max(0, waitingCount + delta);
  const now = waitingCount > 0;
  if (before !== now) listeners.forEach((l) => l(now));
}

/** Called with true while a request is waiting for the network, then false when it is back. */
export function onNetworkWait(l: Listener) {
  listeners.add(l);
  return () => {
    listeners.delete(l);
  };
}

export function isNetworkError(e: unknown) {
  const m = String((e as any)?.message ?? e).toLowerCase();
  return (
    e instanceof TypeError ||
    m.includes("network request failed") ||
    m.includes("failed to fetch") ||
    m.includes("network") ||
    m.includes("timed out") ||
    m.includes("timeout")
  );
}

/**
 * fetch that survives network drops. `retry` defaults to true except for POST: a POST whose answer was lost may
 * already have happened on the server (e.g. starting a workflow), so the caller decides how to resume it.
 */
export async function netFetch(url: string, init: RequestInit & { retry?: boolean } = {}): Promise<Response> {
  const { retry, ...rest } = init;
  const canRetry = retry ?? (rest.method ?? "GET").toUpperCase() !== "POST";
  const started = Date.now();
  let delay = 2000;
  let waiting = false;
  try {
    for (;;) {
      try {
        return await fetch(url, rest);
      } catch (e) {
        if (!isNetworkError(e)) throw e;
        if (!canRetry || Date.now() - started > MAX_WAIT_MS) {
          throw new Error("انقطعت الشبكة. تأكد من الاتصال واضغط «إعادة المحاولة»، العملية بتكمل من مكانها.");
        }
        if (!waiting) {
          waiting = true;
          setWaiting(1);
        }
        await sleep(delay);
        delay = Math.min(delay * 2, 15000);
      }
    }
  } finally {
    if (waiting) setWaiting(-1);
  }
}
