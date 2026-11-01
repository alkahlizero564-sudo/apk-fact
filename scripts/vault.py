"""Private vault: one permanent signing key per app, plus the app's source and details.

Usage (in a workflow, from the repo root):
    python scripts/vault.py --app NAME [--apk PATH] [--notes TEXT] [--build-url URL]

Needs VAULT_TOKEN (secret) and VAULT_REPO (variable, "owner/apk-fact-vault"); without them it prints a
warning and exits 0 so builds keep working. For the app it:
  1. creates a signing key (PKCS12, RSA 2048, 27 years) the first time, then always reuses it;
  2. signs --apk with it (zipalign + apksigner), so every build of the app can update the previous one;
  3. saves apps/NAME/source (the code), apps/NAME/app.json (details) and the key in the vault repo,
     and refreshes vault-index.json and README.md.
"""
import argparse
import datetime
import glob
import json
import os
import re
import secrets
import shutil
import string
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kw)


def now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def detect_lang(src):
    if (src / "lib" / "main.dart").exists():
        return "flutter"
    if (src / "main.py").exists():
        return "python"
    if (src / "MainActivity.kt").exists():
        return "kotlin"
    return "html"


def package_id(app, lang):
    # The same name the builds use (apps/<app>/package.txt or the default).
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import app_id
    return app_id.get(app, lang)


def ensure_key(d, app):
    signing = d / "signing"
    signing.mkdir(parents=True, exist_ok=True)
    ks, info_path = signing / "release.p12", signing / "signing.json"
    if not ks.exists():
        pw = "".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(32))
        print(f"::add-mask::{pw}")
        run(["keytool", "-genkeypair", "-keystore", str(ks), "-storetype", "PKCS12", "-alias", app,
             "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000", "-storepass", pw, "-keypass", pw,
             "-dname", f"CN={app}, O=APK Fact"])
        info_path.write_text(json.dumps({"alias": app, "storePassword": pw, "keyPassword": pw,
                                         "type": "PKCS12", "createdAt": now()}, indent=1) + "\n")
        print(f"Created a new permanent signing key for {app}")
    info = json.loads(info_path.read_text())
    print(f"::add-mask::{info['storePassword']}")
    out = run(["keytool", "-list", "-v", "-keystore", str(ks), "-storetype", "PKCS12",
               "-storepass", info["storePassword"], "-alias", info["alias"]]).stdout
    m = re.search(r"SHA256:\s*([0-9A-F:]+)", out)
    info["sha256"] = m.group(1) if m else ""
    return ks, info


def build_tool(name):
    if os.environ.get(name.upper()):  # override, e.g. APKSIGNER=/path (tests)
        return os.environ[name.upper()]
    home = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT") or ""
    found = sorted(glob.glob(os.path.join(home, "build-tools", "*", name)),
                   key=lambda p: [int(x) if x.isdigit() else 0 for x in re.split(r"[.\-]", Path(p).parent.name)])
    if not found:
        raise SystemExit(f"{name} not found in $ANDROID_HOME/build-tools")
    return found[-1]


def sign(apk, ks, info):
    apk = Path(apk)
    with tempfile.TemporaryDirectory() as tmp:
        aligned, signed = Path(tmp) / "aligned.apk", Path(tmp) / "signed.apk"
        run([build_tool("zipalign"), "-f", "-p", "4", str(apk), str(aligned)])
        run([build_tool("apksigner"), "sign", "--ks", str(ks), "--ks-type", "PKCS12",
             "--ks-key-alias", info["alias"], "--ks-pass", f"pass:{info['storePassword']}",
             "--key-pass", f"pass:{info['keyPassword']}", "--out", str(signed), str(aligned)])
        run([build_tool("apksigner"), "verify", str(signed)])
        shutil.copy(signed, apk)
    print(f"Signed {apk.name} with the permanent key of the app (SHA-256 {info['sha256'][:23]}…)")


def sign_aab(aab, ks, info):
    """Google Play upload: the .aab signed (jarsigner) with the app's permanent key; old signatures removed."""
    import zipfile
    aab = Path(aab)
    with tempfile.TemporaryDirectory() as tmp:
        clean = Path(tmp) / "clean.aab"
        sig = re.compile(r"META-INF/([^/]+\.(SF|RSA|DSA|EC)|MANIFEST\.MF)$", re.I)
        with zipfile.ZipFile(aab) as zin, zipfile.ZipFile(clean, "w", zipfile.ZIP_DEFLATED) as zout:
            for item in zin.infolist():
                if not sig.match(item.filename):
                    zout.writestr(item, zin.read(item.filename))
        run(["jarsigner", "-keystore", str(ks), "-storetype", "PKCS12", "-storepass", info["storePassword"],
             "-keypass", info["keyPassword"], "-sigalg", "SHA256withRSA", "-digestalg", "SHA-256", str(clean), info["alias"]])
        run(["jarsigner", "-verify", str(clean)])
        shutil.copy(clean, aab)
    print(f"Signed {aab.name} for Google Play with the permanent key of the app (SHA-256 {info['sha256'][:23]}…)")


def write_index(vault):
    apps = []
    for f in sorted((vault / "apps").glob("*/app.json")):
        a = json.loads(f.read_text(encoding="utf-8"))
        apps.append({k: a.get(k) for k in ("name", "lang", "packageId", "savedAt", "sha256", "description")})
    (vault / "vault-index.json").write_text(json.dumps({"updatedAt": now(), "apps": apps}, ensure_ascii=False,
                                                       indent=1) + "\n", encoding="utf-8")
    rows = "\n".join(f"| {a['name']} | {a['lang']} | `{a['packageId']}` | {a['savedAt']} |" for a in apps)
    (vault / "README.md").write_text(
        "# APK Fact vault (private)\n\nEach app keeps here its permanent signing key (`signing/`), its source "
        "(`source/`) and its details (`app.json`). Do not make this repository public.\n\n"
        "| App | Language | Package | Last saved |\n|---|---|---|---|\n" + rows + "\n", encoding="utf-8")


def push(vault, message):
    run(["git", "-C", str(vault), "add", "-A"])
    if not run(["git", "-C", str(vault), "status", "--porcelain"]).stdout.strip():
        print("Vault already up to date")
        return
    run(["git", "-C", str(vault), "-c", "user.name=APK Fact", "-c", "user.email=apk-fact@users.noreply.github.com",
         "commit", "-m", message])
    for attempt in range(4):
        try:
            run(["git", "-C", str(vault), "push", "origin", "HEAD"])
            return
        except subprocess.CalledProcessError:
            run(["git", "-C", str(vault), "pull", "--rebase", "origin", "HEAD"])
    raise SystemExit("Could not push to the vault")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--app", required=True)
    ap.add_argument("--apk")
    ap.add_argument("--aab", help="also sign this Google Play bundle (needs the vault)")
    ap.add_argument("--notes", default="")
    ap.add_argument("--build-url", default="")
    ap.add_argument("--require", action="store_true", help="fail instead of warning when the vault is not set up")
    args = ap.parse_args()
    app = args.app
    if not re.fullmatch(r"[a-z0-9-]+", app):
        raise SystemExit("bad app name")

    token, repo = os.environ.get("VAULT_TOKEN", ""), os.environ.get("VAULT_REPO", "")
    url = os.environ.get("VAULT_URL") or (f"https://x-access-token:{token}@github.com/{repo}.git" if token and repo else "")
    if not url and (args.require or args.aab):
        raise SystemExit("الخزنة الخاصة غير مجهّزة. افتح APK Fact > الإعدادات > الخزنة الخاصة واضغط تجهيز.")
    if not url:
        print("::warning::Private vault not set up (open APK Fact > Settings > الخزنة الخاصة). "
              "The APK keeps its temporary signature, so it may not install over an older version.")
        return 0

    src = ROOT / "apps" / app
    with tempfile.TemporaryDirectory() as tmp:
        vault = Path(tmp) / "vault"
        run(["git", "clone", "--depth", "1", url, str(vault)])
        d = vault / "apps" / app
        ks, info = ensure_key(d, app)
        if args.apk:
            sign(args.apk, ks, info)
        if args.aab:
            sign_aab(args.aab, ks, info)

        lang = detect_lang(src)
        if src.exists():
            shutil.rmtree(d / "source", ignore_errors=True)
            shutil.copytree(src, d / "source", ignore=shutil.ignore_patterns("build", ".dart_tool", "__pycache__"))
        meta_path = src / "meta.json"
        meta = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.exists() else {}
        details_path = d / "app.json"
        details = json.loads(details_path.read_text(encoding="utf-8")) if details_path.exists() else {}
        history = meta.get("history", [])
        details.update({
            "name": app,
            "lang": lang,
            "packageId": package_id(app, lang),
            "description": history[0]["request"] if history else details.get("description", ""),
            "changes": [h["request"] for h in history[1:]],
            "sha256": info["sha256"],
            "keyCreatedAt": info.get("createdAt"),
            "savedAt": now(),
            "files": sorted(str(p.relative_to(src)) for p in src.rglob("*") if p.is_file()) if src.exists() else [],
        })
        if args.notes.strip():
            details.setdefault("notes", []).append({"at": now(), "text": args.notes.strip()})
        if args.build_url:
            details.setdefault("builds", []).append({"at": now(), "url": args.build_url})
            details["builds"] = details["builds"][-20:]
        details_path.write_text(json.dumps(details, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        write_index(vault)
        push(vault, f"{'Build' if args.apk else 'Save'}: {app}")
    print(f"Saved {app} in the private vault")
    return 0


if __name__ == "__main__":
    sys.exit(main())
