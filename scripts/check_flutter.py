"""Check a generated Flutter app with the Flutter SDK and fix it before the APK build.

Usage: python scripts/check_flutter.py apps/<name> <flutter project dir> [--rounds N]

The project dir must come from `flutter create`. Each round copies the app's
lib/main.dart and packages into it, then:
  1. `dart fix --apply`: Flutter's own automatic fixes (deprecated APIs etc.),
     written back to the app;
  2. `flutter analyze`: compile errors in seconds instead of a full build;
  3. if errors remain and rounds are left, the AI fixes them (fix_native.py).
Exits 0 when the code analyzes clean, 1 otherwise.
"""
import shutil
import subprocess
import sys
from pathlib import Path

from fix_native import fix
from native_langs import read_deps


def run(cmd, cwd):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    return r.returncode, (r.stdout + r.stderr)


def prepare(app, proj):
    """Copy code and packages into the project; returns (ok, log)."""
    orig = proj / "pubspec.orig.yaml"
    if not orig.exists():
        shutil.copy(proj / "pubspec.yaml", orig)
    shutil.copy(orig, proj / "pubspec.yaml")
    shutil.copy(app / "lib" / "main.dart", proj / "lib" / "main.dart")
    deps = read_deps("flutter", app)
    if deps:
        print(f"Adding packages: {' '.join(deps)}", flush=True)
        return run(["flutter", "pub", "add", *deps], proj)
    return run(["flutter", "pub", "get"], proj)


def analyze(proj):
    code, out = run(["flutter", "analyze", "--no-fatal-infos", "--no-fatal-warnings", "lib/main.dart"], proj)
    errors = [l.strip() for l in out.splitlines() if l.strip().startswith("error")]
    return code == 0, "\n".join(errors) or out[-4000:]


def main():
    args = sys.argv[1:]
    rounds = int(args[args.index("--rounds") + 1]) if "--rounds" in args else 2
    app, proj = Path(args[0]), Path(args[1])
    code_file = app / "lib" / "main.dart"

    for r in range(rounds + 1):
        ok, log = prepare(app, proj)
        if ok != 0:
            problems = "Packages could not be added:\n" + log[-3000:]
        else:
            before = (proj / "lib" / "main.dart").read_text(encoding="utf-8")
            run(["dart", "fix", "--apply", "lib"], proj)
            after = (proj / "lib" / "main.dart").read_text(encoding="utf-8")
            if after != before:
                code_file.write_text(after, encoding="utf-8")
                print("Applied `dart fix` to main.dart", flush=True)
            clean, problems = analyze(proj)
            if clean:
                print("Flutter check passed", flush=True)
                return 0
        print(f"error: Flutter check found problems:\n{problems}", flush=True)
        if r == rounds:
            break
        try:
            fix("flutter", code_file, problems)
        except SystemExit as e:  # no API key, or every model/key failed: retrying won't help now
            print(f"Warning: AI fix failed ({e})", flush=True)
            break
        except Exception as e:  # e.g. an unreadable reply: try again next round
            print(f"Warning: AI fix failed ({e}), trying again", flush=True)
    return 1


if __name__ == "__main__":
    sys.exit(main())
