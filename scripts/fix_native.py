"""Fix a Flutter or Python/Flet app that failed to build: remembered rules first, then AI.

Usage: python scripts/fix_native.py flutter|python path/to/code path/to/build.log
"""
import os
import re
import sys
from pathlib import Path

import fix_memory
from gemini_client import call_gemini
from native_langs import LANGS, rules_for, clean_deps, gemini_keys, parse_reply, read_deps, reply_format, write_deps

DEFAULT_MODEL = "gemini-3.8-flash"



def error_excerpt(log_text):
    lines = log_text.splitlines()
    picked = [l for l in lines if re.search(r"error|Error|Exception|Failed|failed|FAILURE|Traceback|^\s*e: ", l)]
    excerpt = "\n".join(picked[-60:]) if picked else "\n".join(lines[-60:])
    return excerpt[-6000:]


def fix(lang, code_path, log_text, use_memory=True):
    """Fix code_path for the errors in log_text. With use_memory, remembered rules are applied
    first (no AI); the AI then fixes what is left and its one-line fixes are remembered."""
    cfg = LANGS[lang]
    code_path = Path(code_path)
    if use_memory:
        fix_memory.apply(lang, code_path, log_text)
    # The code file lives in apps/<name>/ (Flutter: apps/<name>/lib/main.dart).
    app_dir = code_path.parent.parent if lang == "flutter" else code_path.parent
    code = code_path.read_text(encoding="utf-8")
    errors = error_excerpt(log_text)

    keys = gemini_keys(os.environ)
    if not keys:
        raise SystemExit("No Gemini API key in repository secrets")
    model = os.environ.get("GEMINI_MODEL") or DEFAULT_MODEL

    current_deps = read_deps(lang, app_dir)
    rules = rules_for(lang)
    prompt = f"""The {cfg['title']} app below failed to build. Fix every error with the smallest possible changes.
Keep the app's behavior, screens and design the same.
{rules}

{reply_format([(cfg['fence'], f"the complete fixed {cfg['code_file']}")])}

BUILD ERRORS:
{errors}

PACKAGES CURRENTLY DECLARED: {', '.join(current_deps) or 'none'}

CURRENT {cfg['code_file']}:
{code}
"""
    blocks, deps = parse_reply(call_gemini(model, prompt, keys, temperature=0.2, json_mode=False))
    fixed = blocks.get(cfg["fence"], "")
    if not fixed:
        raise ValueError("Model returned no code block")
    code_path.write_text(fixed + "\n", encoding="utf-8")
    fix_memory.learn(lang, code, fixed, log_text)
    if deps is not None:
        write_deps(lang, app_dir, clean_deps(lang, deps))
    print(f"Applied AI fix to {cfg['code_file']}")


def main():
    log_text = Path(sys.argv[3]).read_text(encoding="utf-8", errors="replace")
    fix(sys.argv[1], sys.argv[2], log_text)


if __name__ == "__main__":
    main()
