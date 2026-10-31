"""Generate (or edit) a Flutter or Python/Flet app and its AI preview.

Usage: python scripts/generate_native.py flutter|python

Reads request-flutter.txt / request-python.txt:
    line 1          app name
    @related: x     optional, another app of the same project to stay consistent with
    @model: x       optional Gemini model
    @preview        optional, only (re)build preview.html from the current code
    rest            description of the app, or of the change
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

from fix_native import fix
from gemini_client import call_gemini
from native_langs import LANGS, clean_deps, gemini_keys, read_deps, write_deps

DEFAULT_MODEL = "gemini-3.8-flash"
HERE = Path(__file__).resolve().parent

PREVIEW_RULES = (
    "\"preview_html\": one self-contained HTML file (inline CSS and JS, no external resources) that "
    "imitates this exact app inside a phone-sized layout, with the same screens, texts, colors, icons "
    "(use emoji or inline SVG) and working behavior (navigation, buttons, forms, lists, local state), "
    "so it can be shown in a WebView as a faithful live preview."
)


def parse_request(text):
    lines = text.splitlines()
    name = re.sub(r"[^a-z0-9-]", "", lines[0].strip().lower())
    related, model, preview_only, body = "", "", False, []
    for line in lines[1:]:
        if line.startswith("@related:"):
            related = re.sub(r"[^a-z0-9-]", "", line.split(":", 1)[1].strip().lower())
        elif line.startswith("@model:"):
            model = line.split(":", 1)[1].strip()
        elif line.strip() == "@preview":
            preview_only = True
        elif line.startswith("(request id:"):
            continue
        else:
            body.append(line)
    return name, related, model, preview_only, "\n".join(body).strip()


def read_app_code(app):
    for lang in LANGS.values():
        p = Path("apps") / app / lang["code_file"]
        if p.exists():
            return p.read_text(encoding="utf-8")[:20000]
    p = Path("apps") / app / "index.html"
    return p.read_text(encoding="utf-8")[:20000] if p.exists() else ""


def parse_json(text):
    text = text.strip()
    text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text)
    return json.loads(text)


def python_problems(code_path):
    """Run the Flet static check, applying its sure fixes; returns the remaining errors, or "" when clean."""
    r = subprocess.run([sys.executable, str(HERE / "check_python.py"), "--fix", str(code_path)],
                       capture_output=True, text=True)
    return "" if r.returncode == 0 else (r.stdout + r.stderr).strip()


def main():
    lang = sys.argv[1]
    cfg = LANGS[lang]
    name, related, model, preview_only, task = parse_request(
        Path(cfg["request_file"]).read_text(encoding="utf-8"))
    if not name or not (task or preview_only):
        raise SystemExit("Bad request file")

    keys = gemini_keys(os.environ)
    if not keys:
        raise SystemExit("No Gemini API key in repository secrets")
    model = model or os.environ.get("GEMINI_MODEL") or DEFAULT_MODEL

    base = Path("apps") / name
    code_path = base / cfg["code_file"]
    existing = code_path.read_text(encoding="utf-8") if code_path.exists() else ""

    if preview_only:
        if not existing:
            raise SystemExit(f"apps/{name}/{cfg['code_file']} does not exist")
        prompt = (f"Here is a {cfg['title']} app. Reply with JSON only, with exactly one string key:\n"
                  f"{PREVIEW_RULES}\n\nApp code:\n```{cfg['fence']}\n{existing}\n```\n")
        if task:
            prompt += f"\nNotes from the user about the preview:\n{task}\n"
        preview = parse_json(call_gemini(model, prompt, keys, temperature=0.3)).get("preview_html", "").strip()
        if not preview:
            raise SystemExit("Model returned no preview_html")
        (base / "preview.html").write_text(preview + "\n", encoding="utf-8")
        print(f"Wrote apps/{name}/preview.html")
        return

    deps_text = ", ".join(cfg["allowed_deps"])
    prompt = f"""{cfg['rules'].format(deps=deps_text)}

Reply with JSON only, with exactly these keys:
"{cfg['code_key']}": the complete {cfg['code_file']} as a string.
"deps": an array with the names of the allowed packages the code uses (can be empty).
{PREVIEW_RULES}

App name: {name}
"""
    context = read_app_code(related) if related and related != name else ""
    if context:
        prompt += f"\nA related app (same project) for reference, keep data and style consistent:\n{context}\n"
    if existing:
        prompt += (f"\nThis is the CURRENT {cfg['code_file']}. Apply the requested change to it and "
                   f"return the full updated files:\n{existing}\n\nRequested change:\n{task}\n")
    else:
        prompt += f"\nDescription of the app to create:\n{task}\n"

    result = parse_json(call_gemini(model, prompt, keys, temperature=0.4))
    code = str(result.get(cfg["code_key"], "")).strip()
    preview = str(result.get("preview_html", "")).strip()
    if not code or not preview:
        raise SystemExit(f"Model did not return both {cfg['code_key']} and preview_html")

    code_path.parent.mkdir(parents=True, exist_ok=True)
    code_path.write_text(code + "\n", encoding="utf-8")
    (base / "preview.html").write_text(preview + "\n", encoding="utf-8")
    deps = clean_deps(lang, result.get("deps")) or (read_deps(lang, base) if existing else [])
    write_deps(lang, base, deps)

    if lang == "python":
        problems = python_problems(code_path)
        if problems:
            print("Generated code has problems, asking AI to fix them:\n" + problems)
            try:
                fix("python", code_path, problems)
            except (Exception, SystemExit) as e:  # keep the generated app; the build step fixes again
                print(f"Warning: AI fix failed ({e}), the build step will try again")
            still = python_problems(code_path)
            if still:
                print("Warning: still not clean, the build step will try again:\n" + still)

    print(f"Wrote apps/{name}/{cfg['code_file']}, preview.html and {cfg['deps_file']} ({', '.join(deps) or 'no extra packages'})")


if __name__ == "__main__":
    main()
