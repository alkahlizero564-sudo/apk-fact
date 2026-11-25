"""Run the real app, look at it, fix what looks wrong, look again — the loop a human developer does.

For a Flutter app of a connected pair, after it is generated:
  1. build its web version (the same Flutter widgets the phone shows);
  2. make a temporary QA account in the pair's Supabase project (an admin for the admin app) and sign it in;
  3. open the app signed in, press its tabs and buttons, photograph every screen, note errors and dead buttons
     (scripts/qa_flutter_web.js);
  4. an AI reviewer looks at the photos next to the approved design and lists what a user would notice;
  5. the AI fixes those in main.dart; the fix is kept only if it still compiles, still passes the wiring gate and the
     second look finds fewer problems;
  6. the QA account and everything it created are deleted.
Never fails a generation: when something here cannot run (no browser, no web build, no key), it says so and skips.

    python scripts/qa_flutter_web.py APP [--rounds 1]
"""
import base64
import io
import json
import os
import re
import secrets
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))


def log(msg):
    print(f"Visual QA: {msg}", flush=True)


# ------------------------------------------------------------------ build

def build_web(app, work):
    """flutter create (web) + the app's code and packages + flutter build web. Returns build/web or None."""
    if not shutil.which("flutter"):
        log("no Flutter SDK here, skipped")
        return None
    proj = work / "web_app"
    r = subprocess.run(["flutter", "create", "--platforms=web", "--project-name", "app_qa", str(proj)],
                       capture_output=True, text=True)
    if r.returncode:
        log("could not create the web project, skipped")
        return None
    import check_flutter
    code, out = check_flutter.prepare(ROOT / "apps" / app, proj)
    if code:
        log(f"packages failed, skipped: {out[-300:]}")
        return None
    r = subprocess.run(["flutter", "build", "web", "--release", "--no-web-resources-cdn"], cwd=proj,
                       capture_output=True, text=True, timeout=900)
    if r.returncode:
        tail = "\n".join(l for l in (r.stdout + r.stderr).splitlines() if "Error" in l or "error" in l)[-800:]
        log(f"the web build failed (a phone-only package?), skipped:\n{tail}")
        return None
    return proj / "build" / "web"


# ------------------------------------------------------------------ QA account

def _http(method, url, headers, body=None):
    req = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, method=method,
                                 headers={"Content-Type": "application/json", **headers})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read().decode()
            return json.loads(raw) if raw.strip() else None
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"{method} {url.split('.co')[-1]} -> {e.code}: {e.read().decode()[:300]}")


class QaAccount:
    """A confirmed account made with the server key, signed in; removed with its data by close()."""

    def __init__(self, st):
        import pair_backend as sb
        self.sb, self.st = sb, st
        self.ref, self.token = st["supabase"]["ref"], os.environ.get("SUPABASE_ACCESS_TOKEN", "")
        self.url, self.anon, self.p = st["supabase"]["url"], st["supabase"]["anonKey"], st["prefix"]
        self.user_id = None
        self.email = f"qa-{secrets.token_hex(4)}@example.com"
        self.password = secrets.token_urlsafe(18)

    def _admin_headers(self, key):
        h = {"apikey": key}
        if not key.startswith("sb_secret_"):
            h["Authorization"] = f"Bearer {key}"
        return h

    def open(self):
        if not self.token:
            raise RuntimeError("no SUPABASE_ACCESS_TOKEN")
        key = self.sb.service_key(self.ref, self.token)
        if not key:
            raise RuntimeError("cannot read the project's server key")
        self.key = key
        if self.st["role"] == "admin":  # the profile trigger makes this account an admin
            self.sb.run_sql(self.ref, self.token, f"insert into public.{self.p}_admins(email) values ('{self.email}') "
                                                  f"on conflict do nothing;")
        u = _http("POST", f"{self.url}/auth/v1/admin/users", self._admin_headers(key),
                  {"email": self.email, "password": self.password, "email_confirm": True,
                   "user_metadata": {"full_name": "مختبر الجودة", "phone": "0900000000"}})
        self.user_id = (u or {}).get("id") or (u or {}).get("user", {}).get("id")
        s = _http("POST", f"{self.url}/auth/v1/token?grant_type=password", {"apikey": self.anon},
                  {"email": self.email, "password": self.password})
        p = self.p
        enc = json.dumps
        return {f"flutter.{p}.access": enc(s["access_token"]), f"flutter.{p}.refresh": enc(s["refresh_token"]),
                f"flutter.{p}.user": enc(s["user"]["id"]), f"flutter.{p}.email": enc(self.email)}

    def close(self):
        try:
            if self.user_id:
                self.sb.run_sql(self.ref, self.token,
                                f"delete from public.{self.p}_notifications where created_by = '{self.user_id}';")
                _http("DELETE", f"{self.url}/auth/v1/admin/users/{self.user_id}", self._admin_headers(self.key))
            self.sb.run_sql(self.ref, self.token, f"delete from public.{self.p}_admins where email = '{self.email}';")
        except Exception as e:
            log(f"could not remove the QA account {self.email} ({e})")


# ------------------------------------------------------------------ look

def capture(build, shots, storage):
    shots.mkdir(parents=True, exist_ok=True)
    sf = shots / "storage.json"
    sf.write_text(json.dumps(storage), encoding="utf-8")
    r = subprocess.run(["node", str(HERE / "qa_flutter_web.js"), str(build), str(shots), str(sf)],
                       capture_output=True, text=True, timeout=1500)
    sf.unlink(missing_ok=True)
    print(r.stdout.strip(), flush=True)
    m = shots / "manifest.json"
    return json.loads(m.read_text(encoding="utf-8")) if m.exists() else []


def _image(path, width=360):
    try:
        from PIL import Image
        im = Image.open(path).convert("RGB")
        if im.width > width:
            im = im.resize((width, round(im.height * width / im.width)))
        buf = io.BytesIO()
        im.save(buf, format="JPEG", quality=78)
        return base64.b64encode(buf.getvalue()).decode(), "image/jpeg"
    except Exception:
        return base64.b64encode(Path(path).read_bytes()).decode(), "image/png"


def design_shots(app, work):
    """Screens of the approved design (scripts/qa_visual.js), or []."""
    out = work / "design"
    subprocess.run(["node", str(HERE / "qa_visual.js"), str(ROOT / "apps" / app), str(out)],
                   capture_output=True, text=True, timeout=300)
    return sorted(out.glob("design_*.png"))[:6] if out.exists() else []


REVIEW = """You are the strictest senior mobile product designer and QA engineer at a top app studio. Above are
screenshots of a REAL {role} app (Arabic, RTL) running signed in{design_note}. The app screenshots are numbered in
this order, with what was pressed to reach each one:
{journey}
{extra}
List EVERY problem a user or an App Store reviewer would notice, most important first. Look for: error / grey /
blank screens; text cut off, overflowing or overlapping; broken alignment or spacing; poor contrast; English,
placeholder or debug text; fake / sample data instead of real data; a press that did nothing; missing loading /
empty / error states; inconsistent colors, fonts, corner radius or icons; anything that looks cheap or unfinished
compared with the best apps on the store{design_rule}.
Be concrete (which screen, which element, what is wrong, how to fix it in Flutter). Do not list things that look fine.
Reply with JSON only: {{"score": <0-10, how close to a top store app>, "problems": [{{"screen": "...",
"problem": "...", "fix": "..."}}]}}"""


def review(app, st, manifest, shots, designs):
    from gemini_client import call_gemini
    from native_langs import gemini_keys
    keys = gemini_keys(os.environ)
    files = [m for m in manifest if m.get("file")]
    if not keys or not files:
        return None
    images = [_image(shots / m["file"]) for m in files[:16]] + [_image(d) for d in designs]
    journey = "\n".join(f"  {i + 1}. " + (" > ".join(m["path"]) or "the first screen after sign-in")
                        for i, m in enumerate(files[:16]))
    dead = [m for m in manifest if not m.get("changed") and m.get("path")]
    errors = sorted({e for m in manifest for e in m.get("errors", [])})
    extra = ""
    if dead:
        extra += "\nPresses that changed NOTHING on screen (likely dead buttons):\n" + "\n".join(
            f"  - {' > '.join(m['path'])}" for m in dead[:12])
    if errors:
        extra += "\nErrors printed by the app while running:\n" + "\n".join(f"  - {e}" for e in errors[:12])
    prompt = REVIEW.format(
        role=st["role"], journey=journey, extra=extra,
        design_note=(f"; after them come {len(designs)} screenshots of the APPROVED design" if designs else ""),
        design_rule=("; and every visible difference from the approved design (layout, colors, components)"
                     if designs else ""))
    model = os.environ.get("GEMINI_MODEL") or "gemini-3.8-flash"
    try:
        text = call_gemini(model, prompt, keys, temperature=0.2, json_mode=True, images=images)
        data = json.loads(re.sub(r"^```(json)?|```$", "", text.strip()))
    except (Exception, SystemExit) as e:
        log(f"the review could not run ({e})")
        return None
    problems = [p for p in data.get("problems", []) if isinstance(p, dict) and p.get("problem")]
    problems += [{"screen": " > ".join(m["path"]), "problem": "pressing it changed nothing visible",
                  "fix": "give it its real action, and a visible response (new screen, updated state or a message)"}
                 for m in dead if not any(m["path"][-1] in str(p.get("screen", "")) for p in problems)][:6]
    return {"score": data.get("score"), "problems": problems, "errors": errors}


def look(app, st, work, tag):
    """Builds, runs and reviews the app as it is now. Returns the review, or None when it could not run."""
    build = build_web(app, work / tag)
    if not build:
        return None
    acc = QaAccount(st)
    try:
        storage = acc.open()
    except Exception as e:
        log(f"no QA account ({e}); the app is looked at signed out")
        storage = {}
    try:
        manifest = capture(build, work / tag / "shots", storage)
    finally:
        acc.close()
    if not manifest:
        log("the app could not be run in the browser, skipped")
        return None
    return review(app, st, manifest, work / tag / "shots", design_shots(app, work / tag))


# ------------------------------------------------------------------ fix

def fix(app, st, found):
    """One AI pass over main.dart with the reviewer's list. Returns the previous code (to roll back) or None."""
    import pair
    import pair_wiring
    from gemini_client import call_gemini
    from native_langs import gemini_keys, parse_reply, rules_for
    import flutter_multi as fm
    app_dir = ROOT / "apps" / app
    f = app_dir / "lib" / "main.dart"
    multi = fm.is_multi(app_dir)
    snap = fm.snapshot(app_dir)
    before = fm.bundle(snap) if multi else f.read_text(encoding="utf-8")
    design = ROOT / "apps" / app / "design.html"
    items = "\n".join(f"- [{p.get('screen', '')}] {p['problem']} -> {p.get('fix', '')}" for p in found["problems"][:25])
    errs = "\n".join(f"- {e}" for e in found.get("errors", [])[:10])
    prompt = (
        f"{rules_for('flutter')}\n\nThis Flutter app was run and every screen was looked at by a strict reviewer. "
        f"Fix EVERY problem below in lib/main.dart, keep everything else (screens, features, data, design) as it is, "
        f"and keep following the contract (backend.dart / auth_screens.dart).\n\nPROBLEMS:\n{items}\n"
        + (f"\nERRORS PRINTED WHILE RUNNING:\n{errs}\n" if errs else "")
        + pair.contract_text(st, st["role"])
        + (f"\nAPPROVED DESIGN:\n```html\n{design.read_text(encoding='utf-8')[:60000]}\n```\n" if design.exists() else "")
        + (f"\nTHE APP'S FILES:\n{before}\n{fm.FILES_REPLY}\n" if multi else
           f"\nReply with exactly one ```dart code block with the complete updated lib/main.dart and a last line "
           f"`DEPS: ` with the packages used, comma separated.\n\nCURRENT lib/main.dart:\n```dart\n{before}\n```\n"))
    call = lambda p: call_gemini(os.environ.get("GEMINI_MODEL") or "gemini-3.8-flash", p, gemini_keys(os.environ),
                                 temperature=0.25, json_mode=False)
    try:
        if multi:
            changed, _ = fm.ask_files(call, prompt)
        else:
            new = parse_reply(call(prompt))[0].get("dart", "")
            changed = {"lib/main.dart": new.rstrip() + "\n"} if len(new) >= len(before) * 0.6 else {}
    except (Exception, SystemExit) as e:
        log(f"no fix ({e})")
        return None
    if not changed:
        log("the fix was empty or much shorter than the app, not used")
        return None
    gaps_before = len(pair_wiring.missing(app))
    fm.write(app_dir, changed)
    import flutter_backend
    flutter_backend.ensure_deps(app_dir)
    if pair_wiring.problems(app, st) or len(pair_wiring.missing(app)) > gaps_before:
        log("the fix broke the build or the wiring, not used")
        fm.restore(app_dir, snap)
        return None
    return snap


def run(app, rounds=1):
    st_path = ROOT / "apps" / app / "pair.json"
    if not st_path.exists() or not (ROOT / "apps" / app / "lib" / "backend.dart").exists():
        return
    st = json.loads(st_path.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        found = look(app, st, work, "look0")
        if found is None:
            return
        log(f"score {found['score']}/10, {len(found['problems'])} problem(s)")
        for p in found["problems"][:25]:
            print(f"  - [{p.get('screen', '')}] {p['problem']}", flush=True)
        for r in range(rounds):
            if not found["problems"]:
                break
            previous = fix(app, st, found)
            if previous is None:
                break
            again = look(app, st, work, f"look{r + 1}")
            if again is None:
                log("fixed, but the second look could not run; keeping the fix (it compiles and passes the gate)")
                break
            better = len(again["problems"]) < len(found["problems"]) or (again.get("score") or 0) > (found.get("score") or 0)
            if not better:
                log(f"the fix did not look better ({len(again['problems'])} problem(s)), going back")
                import flutter_multi
                flutter_multi.restore(ROOT / "apps" / app, previous)
                break
            log(f"after fix {r + 1}: score {again['score']}/10, {len(again['problems'])} problem(s)")
            for p in again["problems"][:15]:
                print(f"  - [{p.get('screen', '')}] {p['problem']}", flush=True)
            found = again


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a or not re.fullmatch(r"[a-z0-9-]+", a[0]):
        raise SystemExit(__doc__)
    try:
        run(a[0], int(a[a.index("--rounds") + 1]) if "--rounds" in a else 1)
    except Exception as e:  # never fails the generation
        log(f"stopped ({e})")
