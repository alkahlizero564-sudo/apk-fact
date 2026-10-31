"""Compile a Kotlin (Jetpack Compose) app and fix its errors: remembered fixes first, then AI.

Usage: python scripts/check_kotlin.py APP_DIR PROJ_DIR [--rounds N]
APP_DIR holds MainActivity.kt (fixed in place, so the fixes are kept); PROJ_DIR is the Android project
made by kotlin_project.py. Exits 0 when the code compiles.
"""
import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

import fix_memory
import kotlin_project
from fix_native import fix


def compile_errors(proj):
    """Run the Kotlin compiler through Gradle; returns (ok, error text)."""
    gradle = shutil.which("gradle") or "gradle"
    r = subprocess.run([gradle, "-p", str(proj), ":app:compileDebugKotlin", "--console=plain", "-q"],
                       capture_output=True, text=True)
    out = r.stdout + r.stderr
    errors = [l.strip() for l in out.splitlines() if re.match(r"\s*e: ", l)]
    if r.returncode == 0:
        return True, ""
    return False, ("\n".join(errors) or out[-5000:])


def count(errors):
    return sum(1 for l in errors.splitlines() if l.startswith("e: ")) or 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("app_dir")
    ap.add_argument("proj")
    ap.add_argument("--rounds", type=int, default=2)
    ap.add_argument("--app", default="")
    ap.add_argument("--version", type=int, default=1)
    a = ap.parse_args()
    app_dir, proj = Path(a.app_dir), Path(a.proj)
    app = a.app or app_dir.name
    code = app_dir / "MainActivity.kt"

    def compile_now():
        kotlin_project.prepare(app_dir, proj, app, a.version)
        return compile_errors(proj)

    ok, errors = compile_now()
    for round_no in range(a.rounds):
        if ok:
            print("Kotlin check passed")
            return 0
        print(f"Compile errors (round {round_no + 1}):\n{errors[:3000]}", flush=True)
        before = code.read_text(encoding="utf-8")
        used = fix_memory.apply("kotlin", code, errors)
        if used:
            ok2, errors2 = compile_now()
            if ok2 or count(errors2) < count(errors):
                ok, errors = ok2, errors2
                if ok:
                    continue
            else:
                code.write_text(before, encoding="utf-8")
                fix_memory.forget("kotlin", used)
        try:
            fix("kotlin", code, errors, use_memory=False)
        except (Exception, SystemExit) as e:
            print(f"AI fix failed: {e}")
        ok, errors = compile_now()
    if ok:
        print("Kotlin check passed")
        return 0
    print("Still has compile errors:\n" + errors[:3000])
    return 1


if __name__ == "__main__":
    sys.exit(main())
