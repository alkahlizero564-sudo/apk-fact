import datetime
import hashlib
import json
import os
import tempfile
import time
import urllib.error
import urllib.request

FALLBACK_MODELS = ["gemini-3.8-flash", "gemini-3.5-flash", "gemini-3.5-flash-lite"]


class GeminiError(Exception):
    def __init__(self, status, body):
        super().__init__(f"{status}: {body[:200]}")
        self.status = status
        self.body = body


# The reply is STREAMED (server-sent events): bytes keep arriving while the model writes, so a long generation is
# never cut off. Without streaming, nothing arrives until the whole file is written, and the 300 s socket timeout
# killed every reply that took longer (a full Flutter app often does) — then it started again from zero.
# The timeout now only fires if the server sends nothing at all for this long (e.g. a very long thinking phase).
# A build sets GEMINI_STALL_SECONDS lower: there an optional AI step must not hold the build for 5 minutes.
STALL_SECONDS = int(os.environ.get("GEMINI_STALL_SECONDS") or 300)


def _request(model, prompt, key, temperature, json_mode=True):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:streamGenerateContent?alt=sse"
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"responseMimeType": "application/json" if json_mode else "text/plain",
                             "temperature": temperature},
    }
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "x-goog-api-key": key},
    )
    out = []
    try:
        with urllib.request.urlopen(req, timeout=STALL_SECONDS) as r:
            for raw in r:  # one "data: {json}" line per chunk
                line = raw.decode("utf-8", "replace").strip()
                if not line.startswith("data:"):
                    continue
                data = line[5:].strip()
                if not data or data == "[DONE]":
                    continue
                try:
                    obj = json.loads(data)
                except ValueError:
                    continue
                if "error" in obj:
                    err = obj["error"]
                    raise GeminiError(err.get("code", -1) if isinstance(err, dict) else -1, json.dumps(err))
                for c in (obj.get("candidates") or [])[:1]:
                    for part in (c.get("content") or {}).get("parts") or []:
                        if part.get("text") and not part.get("thought"):
                            out.append(part["text"])
    except urllib.error.HTTPError as e:
        raise GeminiError(e.code, e.read().decode("utf-8", "replace"))
    except GeminiError:
        raise
    except Exception as e:  # timeout (no bytes for STALL_SECONDS) or network problem
        raise GeminiError(0, str(e))
    text = "".join(out)
    if not text:
        raise GeminiError(-1, "empty or blocked response")
    return text


# Keys out of daily quota, bad keys and retired models are remembered for the whole build job (every step and every
# script of the job share this file), so later calls skip them at once instead of failing on each of them again.
# Keys are stored only as a short hash; the record expires with the day (quotas reset daily).
_DEAD_FILE = os.path.join(os.environ.get("RUNNER_TEMP") or tempfile.gettempdir(), "gemini-dead.json")


def _kid(key):
    return hashlib.sha256(key.encode("utf-8")).hexdigest()[:12]


def _load_dead():
    try:
        with open(_DEAD_FILE, encoding="utf-8") as f:
            d = json.load(f)
        if d.get("day") == datetime.date.today().isoformat():
            return set(d.get("keys", [])), {tuple(x) for x in d.get("pairs", [])}, set(d.get("models", []))
    except (OSError, ValueError):
        pass
    return set(), set(), set()


def _save_dead(keys, pairs, models):
    try:
        with open(_DEAD_FILE, "w", encoding="utf-8") as f:
            json.dump({"day": datetime.date.today().isoformat(), "keys": sorted(keys),
                       "pairs": sorted(list(p) for p in pairs), "models": sorted(models)}, f)
    except OSError:
        pass


def _classify(e):
    body = e.body.lower()
    if e.status in (401, 403) or (e.status == 400 and "api key" in body):
        return "invalid"       # bad key: skip it everywhere
    if e.status == 404:
        return "gone"          # model retired or unknown: never try it again
    if e.status == 429 or "resource_exhausted" in body or "quota" in body:
        if "perday" in body or "per day" in body or "daily" in body:
            return "quota_day"  # this key is out of daily quota for this model
        return "cooldown"       # per-minute rate limit
    return "retry"              # 503, timeout, unknown model: next model now


# GEMINI_PATIENCE_SECONDS (set by the generate workflows): on a busy day (503 "high demand", stalls) keep trying for
# this long before giving up. Five rounds (~10 minutes) were not enough on 19 Nov and the whole pair was lost.
PATIENCE_SECONDS = int(os.environ.get("GEMINI_PATIENCE_SECONDS") or 0)


def call_gemini(model, prompt, keys, temperature=0.3, max_rounds=5, json_mode=True):
    models = [model] + [m for m in FALLBACK_MODELS if m != model]
    started = time.time()
    # A caller asking for one quick try (max_rounds=1, optional AI steps) is never made patient.
    patience = PATIENCE_SECONDS if max_rounds > 1 else 0
    dead_keys, dead_pairs, dead_models = _load_dead()  # by key hash: {kid}, {(kid, model)}, {model}
    cooldown = {}
    last = "no keys"
    skipped = 0
    round_no = -1
    while True:
        round_no += 1
        for m in models:
            if m in dead_models:
                continue
            for n, key in enumerate(keys, start=1):
                k = _kid(key)
                if k in dead_keys or (k, m) in dead_pairs or cooldown.get((k, m), 0) > time.time():
                    skipped += 1
                    continue
                try:
                    return _request(m, prompt, key, temperature, json_mode)
                except GeminiError as e:
                    last = str(e)
                    kind = _classify(e)
                    print(f"Gemini [{m}] key #{n} failed ({kind}): {last}", flush=True)
                    if kind == "invalid":
                        dead_keys.add(k)
                    elif kind == "gone":
                        dead_models.add(m)
                    elif kind == "quota_day":
                        dead_pairs.add((k, m))
                    elif kind == "cooldown":
                        cooldown[(k, m)] = time.time() + 60
                    if kind in ("invalid", "gone", "quota_day"):
                        _save_dead(dead_keys, dead_pairs, dead_models)
                    if kind == "gone":
                        break
                    if kind == "retry":
                        break  # model busy or unreachable: go to the next model now
        if round_no == 0 and skipped:
            print(f"Skipped {skipped} key/model pair(s) already out of today's quota", flush=True)
        all_dead = all(
            m in dead_models or _kid(k) in dead_keys or (_kid(k), m) in dead_pairs
            for m in models
            for k in keys
        )
        out_of_rounds = round_no >= max_rounds - 1 and time.time() - started >= patience
        if all_dead or out_of_rounds:
            break
        # 503 "model overloaded" / timeouts can last a few minutes; back off patiently (15,30,60,90,90…) before giving up.
        wait = min(15 * (2 ** round_no), 90)
        print(f"No model or key available (service busy), waiting {wait}s before the next round"
              + (f" (still trying, {int(time.time() - started)}s of {patience}s)" if patience else ""), flush=True)
        time.sleep(wait)
    raise SystemExit(f"Gemini failed on all keys and models. Last error: {last}")
