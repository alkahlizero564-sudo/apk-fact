import json
import time
import urllib.error
import urllib.request

FALLBACK_MODELS = ["gemini-2.5-flash", "gemini-2.5-flash-lite"]


class GeminiError(Exception):
    def __init__(self, status, body):
        super().__init__(f"{status}: {body[:200]}")
        self.status = status
        self.body = body


def _request(model, prompt, key, temperature):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"responseMimeType": "application/json", "temperature": temperature},
    }
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "x-goog-api-key": key},
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            data = json.load(r)
    except urllib.error.HTTPError as e:
        raise GeminiError(e.code, e.read().decode("utf-8", "replace"))
    except Exception as e:  # timeout or network problem
        raise GeminiError(0, str(e))
    try:
        parts = data["candidates"][0]["content"]["parts"]
        return "".join(p.get("text", "") for p in parts)
    except (KeyError, IndexError):
        raise GeminiError(-1, "empty or blocked response")


def _classify(e):
    body = e.body.lower()
    if e.status in (401, 403) or (e.status == 400 and "api key" in body):
        return "invalid"       # bad key: skip it everywhere
    if e.status == 429 or "resource_exhausted" in body or "quota" in body:
        if "perday" in body or "per day" in body or "daily" in body:
            return "quota_day"  # this key is out of daily quota for this model
        return "cooldown"       # per-minute rate limit
    return "retry"              # 503, timeout, unknown model: next model now


def call_gemini(model, prompt, keys, temperature=0.3, max_rounds=3):
    models = [model] + [m for m in FALLBACK_MODELS if m != model]
    dead_keys = set()
    dead_pairs = set()
    cooldown = {}
    last = "no keys"
    for round_no in range(max_rounds):
        for m in models:
            for n, key in enumerate(keys, start=1):
                pair = (n, m)
                if key in dead_keys or pair in dead_pairs or cooldown.get(pair, 0) > time.time():
                    continue
                try:
                    return _request(m, prompt, key, temperature)
                except GeminiError as e:
                    last = str(e)
                    kind = _classify(e)
                    print(f"Gemini [{m}] key #{n} failed ({kind}): {last}", flush=True)
                    if kind == "invalid":
                        dead_keys.add(key)
                    elif kind == "quota_day":
                        dead_pairs.add(pair)
                    elif kind == "cooldown":
                        cooldown[pair] = time.time() + 60
                    else:
                        break  # model busy or unreachable: go to the next model now
        all_dead = all(
            k in dead_keys or (n, m) in dead_pairs
            for m in models
            for n, k in enumerate(keys, start=1)
        )
        if all_dead or round_no == max_rounds - 1:
            break
        wait = min(10 * (2 ** round_no), 60)
        print(f"No model or key available, waiting {wait}s before the next round", flush=True)
        time.sleep(wait)
    raise SystemExit(f"Gemini failed on all keys and models. Last error: {last}")
