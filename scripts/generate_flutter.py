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
    print(f"Gemini request failed: {last}")
    sys.exit(2)


def parse_json(text):
    text = text.strip()
    text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text)
    return json.loads(text)


def error_excerpt(log_text):
    lines = log_text.splitlines()
    picked = [l for l in lines if re.search(r"error|Error|Exception|Failed|failed|FAILURE|What went wrong", l)]
    excerpt = "\n".join(picked[-60:]) if picked else "\n".join(lines[-60:])
    return excerpt[-6000:]


def main():
    html_path = Path(sys.argv[1])
    log_path = Path(sys.argv[2])
    html = html_path.read_text(encoding="utf-8")
    errors = error_excerpt(log_path.read_text(encoding="utf-8", errors="replace"))

    keys = [k for k in (os.environ.get("GEMINI_API_KEY"), os.environ.get("GEMINI_API_KEY_2"),
                        os.environ.get("GEMINI_API_KEY_3")) if k]
    if not keys:
        print("No Gemini API key in repository secrets")
        sys.exit(2)
    model = os.environ.get("GEMINI_MODEL") or DEFAULT_MODEL

    prompt = f"""An HTML app was wrapped as an Android app (Capacitor) and built with Gradle, and the build failed.
First decide whether the failure is caused by the app's index.html. Gradle, Android SDK, network, plugin or icon problems are NOT caused by it.
If it IS caused by index.html, fix it with the smallest possible changes, keep the design and behavior the same, and return the complete file.
Reply with JSON only, with exactly two keys:
"caused_by_html": true or false
"index_html": the complete fixed index.html if caused_by_html is true, otherwise an empty string.

BUILD LOG (errors):
{errors}

CURRENT index.html:
{html}
"""
    result = parse_json(call_gemini(model, prompt, keys))
    if not result.get("caused_by_html"):
        print("The failure is not caused by index.html")
        sys.exit(3)
    fixed = (result.get("index_html") or "").strip()
    if not fixed:
        print("Model returned no code")
        sys.exit(2)
    html_path.write_text(fixed + "\n", encoding="utf-8")
    print("Applied AI fix to index.html")


if __name__ == "__main__":
    main()
