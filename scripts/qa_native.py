"""Deep quality check for a real native APK on an Android emulator (the on-demand gate).

Runs inside a booted emulator (adb available). It installs the APK, launches it, and checks that the real app
actually runs: it does not crash on start, it renders something (not a blank screen), and it survives pressing a
few of its on-screen controls. It saves screenshots so a person (or the visual check) can look at the real app.

    python scripts/qa_native.py --apk app.apk --package com.generated.app_x [--shots DIR] [--taps 6]

Exit 0 when the app launched and did not crash (problems, if any, are printed as warnings); exit 1 only when the
app crashed or never came up. Best-effort and defensive: every adb call has a timeout and is caught.
"""
import argparse
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path


def adb(*args, timeout=60, binary=False):
    try:
        r = subprocess.run(["adb", *args], capture_output=True, timeout=timeout)
        return r.stdout if binary else r.stdout.decode("utf-8", "replace")
    except Exception as e:
        print(f"adb {' '.join(args)} failed: {e}", flush=True)
        return b"" if binary else ""


def wait_for_device():
    adb("wait-for-device", timeout=180)
    for _ in range(60):
        if adb("shell", "getprop", "sys.boot_completed").strip() == "1":
            return True
        time.sleep(2)
    return False


def running(pkg):
    return bool(adb("shell", "pidof", pkg).strip())


def crash_lines(pkg):
    """Fatal crashes / ANRs for this package from the log's crash buffer."""
    log = adb("logcat", "-d", "-b", "crash", "-t", "400")
    main = adb("logcat", "-d", "-t", "600")
    out = []
    for block in (log, main):
        for m in re.finditer(r"(FATAL EXCEPTION[\s\S]{0,400})", block):
            chunk = m.group(1)
            if pkg.split(".")[-1] in block or pkg in block or "AndroidRuntime" in chunk:
                first = " ".join(l.strip() for l in chunk.splitlines()[:4])
                if first not in out:
                    out.append(first)
    if re.search(rf"ANR in {re.escape(pkg)}", main):
        out.append(f"ANR (app not responding) in {pkg}")
    return out[:5]


def blank(shot_png):
    """True when the screenshot is essentially one flat colour (nothing rendered)."""
    try:
        from PIL import Image
        import io
        im = Image.open(io.BytesIO(shot_png)).convert("RGB").resize((48, 96))
        colors = im.getcolors(48 * 96) or []
        if not colors:
            return False
        top = max(colors, key=lambda c: c[0])[0]
        return top / (48 * 96) > 0.985  # >98.5% one colour
    except Exception:
        return False


def clickable_nodes():
    adb("shell", "uiautomator", "dump", "/sdcard/ui.xml", timeout=40)
    xml = adb("shell", "cat", "/sdcard/ui.xml", timeout=20)
    nodes = []
    try:
        root = ET.fromstring(xml)
    except Exception:
        return nodes
    for n in root.iter("node"):
        if n.get("clickable") == "true" and n.get("enabled") == "true":
            b = re.findall(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", n.get("bounds", ""))
            if b:
                x1, y1, x2, y2 = map(int, b[0])
                if x2 > x1 and y2 > y1:
                    nodes.append(((x1 + x2) // 2, (y1 + y2) // 2, (n.get("text") or n.get("content-desc") or "control")[:40]))
    return nodes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apk", required=True)
    ap.add_argument("--package", required=True)
    ap.add_argument("--shots", default="")
    ap.add_argument("--taps", type=int, default=6)
    a = ap.parse_args()
    pkg = a.package
    shots = Path(a.shots) if a.shots else None
    if shots:
        shots.mkdir(parents=True, exist_ok=True)
    problems = []

    if not wait_for_device():
        print("::warning::emulator did not finish booting")
    adb("install", "-r", "-g", a.apk, timeout=180)

    # Launch via the launcher intent (no need to know the activity name).
    adb("shell", "monkey", "-p", pkg, "-c", "android.intent.category.LAUNCHER", "1", timeout=60)
    time.sleep(6)

    launched = running(pkg)
    crashes = crash_lines(pkg)
    if crashes:
        problems += [f"CRASH: {c}" for c in crashes]
    if not launched and not crashes:
        problems.append("the app did not start (its process is not running and no crash was logged)")

    shot = adb("exec-out", "screencap", "-p", binary=True, timeout=30)
    shot_n = 0
    if shots and shot:
        shot_n += 1
        (shots / f"app_{shot_n:02d}.png").write_bytes(shot)  # app_NN.png: read by qa_visual.py for the visual check
    if shot and blank(shot):
        problems.append("the first screen is blank (nothing rendered)")

    # Press a few controls and watch for a crash after each.
    pressed = 0
    if launched and not crashes:
        for i, (x, y, label) in enumerate(clickable_nodes()[: a.taps]):
            adb("shell", "input", "tap", str(x), str(y), timeout=20)
            pressed += 1
            time.sleep(2)
            c = crash_lines(pkg)
            if c:
                problems += [f"CRASH after pressing «{label}»: {c[0]}"]
                break
            if shots:
                s = adb("exec-out", "screencap", "-p", binary=True, timeout=30)
                if s:
                    shot_n += 1
                    (shots / f"app_{shot_n:02d}.png").write_bytes(s)

    print(f"QA (emulator): launched={launched}, pressed {pressed} control(s), {len(crashes)} crash(es)", flush=True)
    if problems:
        print("\nNative app problems found:")
        for p in problems:
            print("- " + p)
    else:
        print("QA (emulator): the app launched, rendered and survived its controls — no crash found.")

    # Fail only on a real crash / no-launch (so the gate is meaningful); other notes are warnings.
    fatal = any(p.startswith("CRASH") or "did not start" in p for p in problems)
    raise SystemExit(1 if fatal else 0)


if __name__ == "__main__":
    main()
