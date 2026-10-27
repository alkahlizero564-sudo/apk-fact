import json
import os
import re
from pathlib import Path

from gemini_client import call_gemini

DEFAULT_MODEL = "gemini-2.5-flash"


def parse_request(text):
    lines = text.splitlines()
    name = re.sub(r"[^a-z0-9-]", "", lines[0].strip().lower())
    related, model, body = "", "", []
    for line in lines[1:]:
        if line.startswith("@related:"):
            related = line.split(":", 1)[1].strip()
        elif line.startswith("@model:"):
            model = line.split(":", 1)[1].strip()
        elif line.startswith("(request id:"):
            continue
        else:
            body.append(line)
    return name, related, model, "\n".join(body).strip()


def read_app_code(app):
    for rel in ("lib/main.dart", "index.html"):
        p = Path("apps") / app / rel
        if p.exists():
            return p.read_text(encoding="utf-8")[:20000]
    return ""


def parse_json(text):
    text = text.strip()
    text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text)
    return json.loads(text)


def main():
    name, related, model, task = parse_request(Path("request-flutter.txt").read_text(encoding="utf-8"))
    if not name or not task:
        raise SystemExit("Bad request file")

    keys = [k for k in (os.environ.get("GEMINI_API_KEY"), os.environ.get("GEMINI_API_KEY_2"),
                        os.environ.get("GEMINI_API_KEY_3")) if k]
    if not keys:
        raise SystemExit("No Gemini API key in repository secrets")

    existing = read_app_code(name)
    context = read_app_code(related) if related and related != name else ""

    prompt = f"""You write Flutter apps. Reply with JSON only, with exactly two string keys:
"main_dart": the complete lib/main.dart. A single file, using only the Flutter SDK (material.dart). No pub.dev packages. Material 3. If the description is Arabic, make the UI RTL.
"preview_html": one self-contained HTML file (inline CSS and JS, no external resources) that imitates this exact Flutter app inside a phone-sized layout, with the same screens, texts, colors and behavior, so it can be shown in a WebView.

App name: {name}
"""
    if context:
        prompt += f"\nA related app (same project) for reference, keep data and style consistent:\n{context}\n"
    if existing:
        prompt += f"\nThis is the CURRENT lib/main.dart (or HTML). Apply the requested change to it and return the full updated files:\n{existing}\n\nRequested change:\n{task}\n"
    else:
        prompt += f"\nDescription of the app to create:\n{task}\n"

    result = parse_json(call_gemini(model or DEFAULT_MODEL, prompt, keys, temperature=0.4))
    main_dart = result.get("main_dart", "").strip()
    preview = result.get("preview_html", "").strip()
    if not main_dart or not preview:
        raise SystemExit("Model did not return both main_dart and preview_html")

    base = Path("apps") / name
    (base / "lib").mkdir(parents=True, exist_ok=True)
    (base / "lib" / "main.dart").write_text(main_dart + "\n", encoding="utf-8")
    (base / "preview.html").write_text(preview + "\n", encoding="utf-8")
    print(f"Wrote apps/{name}/lib/main.dart and preview.html")


if __name__ == "__main__":
    main()
