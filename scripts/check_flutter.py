"""Check a generated Flutter app with the Flutter SDK and fix it before the APK build.

Usage: python scripts/check_flutter.py apps/<name> <flutter project dir> [--rounds N]

The project dir must come from `flutter create`. Each round copies the app's
lib/main.dart and packages into it, then:
  1. `dart fix --apply`: Flutter's own automatic fixes (deprecated APIs etc.),
     written back to the app;
  2. `flutter analyze`: compile errors in seconds instead of a full build;
  3. remembered fixes (fix_memory.py) on the reported lines, without AI; kept only if they help;
  4. if errors remain and rounds are left, the AI fixes them and its fixes are remembered.
Exits 0 when the code analyzes clean, 1 otherwise.
"""
import shutil
import subprocess
import sys
from pathlib import Path

import fix_memory
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
    for f in (app / "lib").rglob("*.dart"):  # main.dart, helpers, and lib/screens/* of a multi-file app
        dest = proj / f.relative_to(app)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(f, dest)
    deps = read_deps("flutter", app)
    if deps:
        print(f"Adding packages: {' '.join(deps)}", flush=True)
        return run(["flutter", "pub", "add", *deps], proj)
    return run(["flutter", "pub", "get"], proj)


def analyze(proj, target="lib/main.dart"):
    code, out = run(["flutter", "analyze", "--no-fatal-infos", "--no-fatal-warnings", target], proj)
    errors = [l.strip() for l in out.splitlines() if l.strip().startswith("error")]
    return code == 0, "\n".join(errors) or out[-4000:]


def count_errors(problems):
    return sum(1 for l in problems.splitlines() if l.startswith("error")) or 1


def try_memory(app, proj, code_file, problems):
    """Apply remembered fixes; keep them only if the analyzer agrees. Returns (clean, problems)."""
    before = code_file.read_text(encoding="utf-8")
    used = fix_memory.apply("flutter", code_file, problems)
    if not used:
        return False, problems
    shutil.copy(code_file, proj / "lib" / "main.dart")
    clean, after = analyze(proj)
    if clean or count_errors(after) < count_errors(problems):
        return clean, after
    code_file.write_text(before, encoding="utf-8")
    shutil.copy(code_file, proj / "lib" / "main.dart")
    fix_memory.forget("flutter", used)
    return False, problems


def main():
    args = sys.argv[1:]
    rounds = int(args[args.index("--rounds") + 1]) if "--rounds" in args else 2
    app, proj = Path(args[0]), Path(args[1])
    code_file = app / "lib" / "main.dart"
    import flutter_multi
    multi = flutter_multi.is_multi(app)  # built screen by screen: check every file, fix the ones with errors
    target = "lib" if multi else "lib/main.dart"

    for r in range(rounds + 1):
        ok, log = prepare(app, proj)
        if ok != 0:
            problems = "Packages could not be added:\n" + log[-3000:]
        else:
            mine = list(flutter_multi.own_files(app)) if multi else ["lib/main.dart"]
            before = {rel: (proj / rel).read_text(encoding="utf-8") for rel in mine}
            run(["dart", "fix", "--apply", "lib"], proj)
            for rel in mine:
                after = (proj / rel).read_text(encoding="utf-8")
                if after != before[rel]:
                    (app / rel).write_text(after, encoding="utf-8")
                    print(f"Applied `dart fix` to {Path(rel).name}", flush=True)
            clean, problems = analyze(proj, target)
            if not clean and not multi:
                clean, problems = try_memory(app, proj, code_file, problems)
            if clean:
                print("Flutter check passed", flush=True)
                return 0
        print(f"error: Flutter check found problems:\n{problems}", flush=True)
        if r == rounds:
            break
        try:
            if multi:
                from fix_native import fix_app
                fix_app(app, problems)
            else:
                fix("flutter", code_file, problems, use_memory=False)
        except SystemExit as e:  # no API key, or every model/key failed: retrying won't help now
            print(f"Warning: AI fix failed ({e})", flush=True)
            break
        except Exception as e:  # e.g. an unreadable reply: try again next round
            print(f"Warning: AI fix failed ({e}), trying again", flush=True)
    return 1


if __name__ == "__main__":
    sys.exit(main())
