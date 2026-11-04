"""The public updates repo: where built APK/AAB files and apps/<app>/version.json are published.

When apk-fact is private (so the apps' code, descriptions and build logs are hidden), installed apps still need a
public place to check for updates and download them. APK Fact creates <owner>/apk-fact-updates for that
(Settings > الخصوصية) and sets the UPDATES_REPO variable and the UPDATES_TOKEN secret. It holds no code.
Without UPDATES_REPO everything is published in this repo, as before.

    python scripts/updates_repo.py release TAG TITLE NOTES FILE...  -> GitHub release with the files; prints its download base URL
    python scripts/updates_repo.py base TAG                         -> prints the download base URL of TAG
    python scripts/updates_repo.py mirror APP                       -> copies apps/APP/version.json to the updates repo
"""
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def target():
    """(repo, token) the files go to."""
    repo = os.environ.get("UPDATES_REPO", "").strip()
    if repo:
        token = os.environ.get("UPDATES_TOKEN", "").strip()
        if not token:
            raise SystemExit("UPDATES_REPO is set but the UPDATES_TOKEN secret is missing (APK Fact > الإعدادات > الخصوصية)")
        return repo, token
    return os.environ["GITHUB_REPOSITORY"], os.environ.get("GH_TOKEN", "")


def base(tag):
    return f"https://github.com/{target()[0]}/releases/download/{tag}"


def release(tag, title, notes, files):
    """Creates the release with its files. GitHub sometimes answers 502/500 (build 83 of APK Fact was lost to
    one), so it tries 5 times; when the release was made but a file did not upload, the file is uploaded again."""
    import time
    repo, token = target()
    env = {**os.environ, "GH_TOKEN": token}
    for attempt in range(5):
        exists = subprocess.run(["gh", "release", "view", tag, "--repo", repo], env=env, capture_output=True).returncode == 0
        cmd = (["gh", "release", "upload", tag, *files, "--repo", repo, "--clobber"] if exists else
               ["gh", "release", "create", tag, *files, "--repo", repo, "--title", title, "--notes", notes])
        if subprocess.run(cmd, env=env).returncode == 0:
            print(base(tag))
            return
        print(f"GitHub did not take the release (try {attempt + 1} of 5), trying again…", flush=True)
        time.sleep(10 * (attempt + 1))
    raise SystemExit(f"Could not publish release {tag} to {repo} after 5 tries")


def mirror(app):
    repo = os.environ.get("UPDATES_REPO", "").strip()
    if not repo:
        return
    if not re.fullmatch(r"[a-z0-9-]+", app):
        raise SystemExit("bad app name")
    _, token = target()
    src = ROOT / "apps" / app / "version.json"
    with tempfile.TemporaryDirectory() as tmp:
        url = os.environ.get("UPDATES_GIT_URL") or f"https://x-access-token:{token}@github.com/{repo}.git"  # override: tests
        run = lambda *c: subprocess.run(["git", "-C", tmp, *c], check=True, capture_output=True, text=True)
        subprocess.run(["git", "clone", "--depth", "1", url, tmp], check=True, capture_output=True)
        dest = Path(tmp) / "apps" / app / "version.json"
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(src.read_bytes())
        run("add", "-A")
        if not run("status", "--porcelain").stdout.strip():
            print("Updates repo already has this version")
            return
        run("-c", "user.name=APK Fact", "-c", "user.email=apk-fact@users.noreply.github.com", "commit", "-m", f"{app}: new version")
        for i in range(4):
            try:
                run("push", "origin", "HEAD")
                print(f"Installed copies of {app} will see the update ({repo})")
                return
            except subprocess.CalledProcessError:
                time.sleep(3 * (i + 1))
                run("pull", "--rebase", "origin", "HEAD")
        raise SystemExit("Could not push to the updates repo")


def main():
    cmd, *a = sys.argv[1:] or ["help"]
    if cmd == "release" and len(a) >= 4:
        release(a[0], a[1], a[2], a[3:])
    elif cmd == "base" and a:
        print(base(a[0]))
    elif cmd == "mirror" and a:
        mirror(a[0])
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
