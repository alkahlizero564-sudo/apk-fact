import json
import time
import urllib.error
import urllib.request


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
    if e.status == 429 or "resource_exhausted" in body or "quota" in body:
        if "perday" in body or "per day" in body or "daily" in body:
            return "dead"      # out of daily quota
        return "cooldown"      # per-minute rate limit
    if e.status in (401, 403) or (e.status == 400 and "api key" in body):
        return "dead"          # invalid or blocked key
    return "retry"             # 500, 503, timeout, empty response


def call_gemini(model, prompt, keys, temperature=0.3, max_rounds=4):
    dead = set()
    cooldown = {}
    last = "no keys"
    for round_no in range(max_rounds):
        for n, key in enumerate(keys, start=1):
            if key in dead or cooldown.get(key, 0) > time.time():
                continue
            try:
                return _request(model, prompt, key, temperature)
            except GeminiError as e:
                last = str(e)
                kind = _classify(e)
                print(f"Gemini key #{n} failed ({kind}): {last}", flush=True)
                if kind == "dead":
                    dead.add(key)
                elif kind == "cooldown":
                    cooldown[key] = time.time() + 60
        if len(dead) == len(keys):
            break
        if round_no == max_rounds - 1:
            break
        wait = min(15 * (2 ** round_no), 90)
        print(f"No key available, waiting {wait}s before the next round", flush=True)
        time.sleep(wait)
    raise SystemExit(f"Gemini failed on all keys. Last error: {last}")
