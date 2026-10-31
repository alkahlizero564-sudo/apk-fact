"""Ask AI to fix a Flutter or Python/Flet app that failed to build.

Usage: python scripts/fix_native.py flutter|python path/to/code path/to/build.log
"""
import json
import os
import re
import sys
from pathlib import Path

from gemini_client import call_gemini
from native_langs import LANGS, clean_deps, gemini_keys, read_deps, write_deps

DEFAULT_MODEL = "gemini-3.8-flash"


def parse_json(text):
    text = text.strip()
    text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text)
    return json.loads(text)


def error_excerpt(log_text):
    lines = log_text.splitlines()
    picked = [l for l in lines if re.search(r"error|Error|Exception|Failed|failed|FAILURE|Traceback", l)]
    excerpt = "\n".join(picked[-60:]) if picked else "\n".join(lines[-60:])
    return excerpt[-6000:]


def fix(lang, code_path, log_text):
    cfg = LANGS[lang]
    code_path = Path(code_path)
    # The code file lives in apps/<name>/ (Flutter: apps/<name>/lib/main.dart).
    app_dir = code_path.parent.parent if lang == "flutter" else code_path.parent
    code = code_path.read_text(encoding="utf-8")
    errors = error_excerpt(log_text)

    keys = gemini_keys(os.environ)
    if not keys:
        raise SystemExit("No Gemini API key in repository secrets")
    model = os.environ.get("GEMINI_MODEL") or DEFAULT_MODEL

    current_deps = read_deps(lang, app_dir)
    rules = cfg["rules"].format(deps=", ".join(cfg["allowed_deps"]))
    prompt = f"""The {cfg['title']} app below failed to build. Fix every error with the smallest possible changes.
Keep the app's behavior, screens and design the same.
{rules}

Reply with JSON only, with exactly these keys:
"{cfg['code_key']}": the complete fixed {cfg['code_file']} as a string.
"deps": an array with the names of the allowed packages the fixed code uses.

BUILD ERRORS:
{errors}

PACKAGES CURRENTLY DECLARED: {', '.join(current_deps) or 'none'}

CURRENT {cfg['code_file']}:
{code}
"""
    result = parse_json(call_gemini(model, prompt, keys, temperature=0.2))
    fixed = str(result.get(cfg["code_key"], "")).strip()
    if not fixed:
        raise SystemExit("Model returned no code")
    code_path.write_text(fixed + "\n", encoding="utf-8")
    if "deps" in result:
        write_deps(lang, app_dir, clean_deps(lang, result.get("deps")))
    print(f"Applied AI fix to {cfg['code_file']}")


def main():
    log_text = Path(sys.argv[3]).read_text(encoding="utf-8", errors="replace")
    fix(sys.argv[1], sys.argv[2], log_text)


if __name__ == "__main__":
    main()
