import os
import re
import sys
from pathlib import Path

from gemini_client import call_gemini
from native_langs import parse_reply

DEFAULT_MODEL = "gemini-3.8-flash"


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

    prompt = f"""An HTML app is wrapped as an Android app (Capacitor) and built with Gradle. Either the build failed,
or a pre-build check found JavaScript errors in index.html (those are always caused by index.html).
First decide whether the failure is caused by the app's index.html. Gradle, Android SDK, network, plugin or icon problems are NOT caused by it.
If it IS caused by index.html, fix it with the smallest possible changes, keep the design and behavior the same, and return the complete file.
Reply in exactly this format, nothing else:
1. a first line `CAUSED_BY_HTML: yes` or `CAUSED_BY_HTML: no`
2. if yes, one ```html code block with the complete fixed index.html

BUILD LOG (errors):
{errors}

CURRENT index.html:
{html}
"""
    try:
        raw = call_gemini(model, prompt, keys, temperature=0.2, json_mode=False)
    except SystemExit as e:
        print(e.code)
        sys.exit(2)

    fixed = parse_reply(raw)[0].get("html", "")
    if not fixed and re.search(r"CAUSED_BY_HTML:\s*no", raw, re.I):
        print("The failure is not caused by index.html")
        sys.exit(3)
    if not fixed:
        print("Model returned no code")
        sys.exit(2)
    html_path.write_text(fixed + "\n", encoding="utf-8")
    print("Applied AI fix to index.html")


if __name__ == "__main__":
    main()
