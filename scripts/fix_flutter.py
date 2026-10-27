import json
import os
import re
import sys
import urllib.request
from pathlib import Path

DEFAULT_MODEL = "gemini-2.5-flash"


def call_gemini(model, prompt, keys):
    last = None
    for key in keys:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"responseMimeType": "application/json", "temperature": 0.2},
        }
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json", "x-goog-api-key": key},
        )
        try:
            with urllib.request.urlopen(req, timeout=240) as r:
                data = json.load(r)
            parts = data["candidates"][0]["content"]["parts"]
            return "".join(p.get("text", "") for p in parts)
        except Exception as e:  # try the next key
            last = e
    raise SystemExit(f"Gemini request failed: {last}")


def parse_json(text):
    text = text.strip()
    text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text)
    return json.loads(text)


def error_excerpt(log_text):
    lines = log_text.splitlines()
    picked = [l for l in lines if re.search(r"error|Error|Exception|Failed|failed|FAILURE", l)]
    excerpt = "\n".join(picked[-60:]) if picked else "\n".join(lines[-60:])
    return excerpt[-6000:]


def main():
    code_path = Path(sys.argv[1])
    log_path = Path(sys.argv[2])
    code = code_path.read_text(encoding="utf-8")
    errors = error_excerpt(log_path.read_text(encoding="utf-8", errors="replace"))

    keys = [k for k in (os.environ.get("GEMINI_API_KEY"), os.environ.get("GEMINI_API_KEY_2"),
                        os.environ.get("GEMINI_API_KEY_3")) if k]
    if not keys:
        raise SystemExit("No Gemini API key in repository secrets")
    model = os.environ.get("GEMINI_MODEL") or DEFAULT_MODEL

    prompt = f"""The Flutter app below failed to build. Fix every compile error with the smallest possible changes.
Keep the app's behavior, screens and design the same. Use only the Flutter SDK (material.dart), no pub.dev packages.
Reply with JSON only, with exactly one string key "main_dart" that holds the complete fixed lib/main.dart.

BUILD ERRORS:
{errors}

CURRENT lib/main.dart:
{code}
"""
    result = parse_json(call_gemini(model, prompt, keys))
    fixed = result.get("main_dart", "").strip()
    if not fixed:
        raise SystemExit("Model returned no code")
    code_path.write_text(fixed + "\n", encoding="utf-8")
    print("Applied AI fix to main.dart")


if __name__ == "__main__":
    main()
