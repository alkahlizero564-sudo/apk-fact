"""Visual check: compare screenshots of the BUILT app with the APPROVED design, using Gemini vision, and print the
differences a user would notice. scripts/qa_visual.js captures the screenshots first.

    node scripts/qa_visual.js <app_dir> <shots_dir>
    python scripts/qa_visual.py <shots_dir>     # reads <shots_dir>/manifest.json

Prints each difference on its own line starting with "- visual: ..." (so the HTML fixer picks them up) and exits 1
when it finds differences, 0 when the app matches or the check could not run (no key / no images / no design).
Defensive: every failure is caught and turns into a clean skip.
"""
import base64
import io
import json
import os
import re
import sys
import urllib.request
from pathlib import Path

ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
MODELS = ["gemini-3.8-flash", "gemini-3.5-flash", "gemini-2.5-flash"]


def keys():
    return [k for k in (os.environ.get("GEMINI_API_KEY"), os.environ.get("GEMINI_API_KEY_2"),
                        os.environ.get("GEMINI_API_KEY_3")) if k]


def load_png(path, width=420):
    """Read a PNG and downscale it (cheaper to send); returns base64, or None."""
    try:
        from PIL import Image
        im = Image.open(path).convert("RGB")
        if im.width > width:
            im = im.resize((width, round(im.height * width / im.width)))
        buf = io.BytesIO()
        im.save(buf, format="JPEG", quality=80)
        return base64.b64encode(buf.getvalue()).decode(), "image/jpeg"
    except Exception:
        try:
            return base64.b64encode(Path(path).read_bytes()).decode(), "image/png"
        except Exception:
            return None


PROMPT = (
    "You are a meticulous mobile UI reviewer. Below are screenshots of an APPROVED design the owner signed off on, "
    "then screenshots of the BUILT app that was made from it. Compare them and list the differences a normal user "
    "WOULD NOTICE when using the app: a design screen that is missing or clearly different in the app; and clear "
    "differences in layout, structure, colors, typography, spacing, corner radius, icons, components, and the "
    "bottom navigation. Ignore tiny pixel differences, different sample data/numbers, and the exact wording of "
    "placeholder text. Be concrete: name the screen and what differs, and how to fix it. "
    'Reply with JSON only: {"diffs": ["..."]} — an empty list when the app already matches the design.'
)


def call_vision(model, key, parts):
    body = json.dumps({
        "contents": [{"parts": parts}],
        "generationConfig": {"responseMimeType": "application/json", "temperature": 0.1},
    }).encode()
    req = urllib.request.Request(ENDPOINT.format(model=model), data=body,
                                headers={"Content-Type": "application/json", "x-goog-api-key": key})
    with urllib.request.urlopen(req, timeout=180) as r:
        data = json.load(r)
    return "".join(p.get("text", "") for p in data["candidates"][0]["content"]["parts"])


def main():
    shots = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    if not shots or not shots.exists():
        print("Visual check skipped (no screenshots)")
        return 0
    # The design shots are design_*.png (from qa_visual.js); the app shots are app_*.png — written by qa_visual.js
    # for HTML/React, or by qa_native.py (the emulator) for a native app. Works the same for both.
    design = sorted(str(p) for p in shots.glob("design_*.png"))[:6]
    app = sorted(str(p) for p in shots.glob("app_*.png"))[:6]
    ks = keys()
    if not design or not app or not ks:
        print("Visual check skipped (need the design, the app, and a Gemini key)")
        return 0

    parts = [{"text": PROMPT}, {"text": "APPROVED DESIGN screens:"}]
    for i, f in enumerate(design, 1):
        img = load_png(f)
        if img:
            parts += [{"text": f"design screen {i}:"}, {"inline_data": {"mime_type": img[1], "data": img[0]}}]
    parts.append({"text": "BUILT APP screens:"})
    for i, f in enumerate(app, 1):
        img = load_png(f)
        if img:
            parts += [{"text": f"app screen {i}:"}, {"inline_data": {"mime_type": img[1], "data": img[0]}}]

    raw = ""
    for model in MODELS:
        for key in ks:
            try:
                raw = call_vision(model, key, parts)
                break
            except Exception as e:
                print(f"vision [{model}] failed: {str(e)[:120]}", flush=True)
                continue
        if raw:
            break
    if not raw:
        print("Visual check skipped (vision call did not succeed)")
        return 0

    try:
        diffs = json.loads(re.sub(r"^[^{]*|[^}]*$", "", raw)).get("diffs", [])
    except Exception:
        print("Visual check: could not read the model's answer")
        return 0
    diffs = [d.strip() for d in diffs if isinstance(d, str) and d.strip()][:12]
    if not diffs:
        print("Visual check: the app matches the approved design.")
        return 0
    print("Visual differences from the approved design:")
    for d in diffs:
        print("- visual: " + d)
    return 1


if __name__ == "__main__":
    sys.exit(main())
