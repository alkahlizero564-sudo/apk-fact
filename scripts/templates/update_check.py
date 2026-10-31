"""In-app updates (added by APK Fact at build time; not part of the app's own code).

Importing this module wraps ft.run so that, after the app's own main() has built its screen, the app
checks for a newer published version and offers it in a dialog.
"""
import asyncio
import inspect
import json
import time
import urllib.request

import flet as ft

APKFACT_VERSION = __APKFACT_VERSION__
APKFACT_MANIFEST = "__APKFACT_MANIFEST__"


def _fetch():
    try:
        url = f"{APKFACT_MANIFEST}?t={int(time.time())}"
        with urllib.request.urlopen(url, timeout=10) as r:
            m = json.loads(r.read().decode("utf-8"))
        if isinstance(m, dict) and isinstance(m.get("version"), int) and m["version"] > APKFACT_VERSION and m.get("apk"):
            return m
    except Exception:
        pass
    return None


def _show(page, m):
    async def update(e):
        page.pop_dialog()
        await ft.UrlLauncher().launch_url(m["apk"], mode=ft.LaunchMode.EXTERNAL_APPLICATION)

    def later(e):
        page.pop_dialog()

    page.show_dialog(
        ft.AlertDialog(
            rtl=True,
            icon=ft.Icon(ft.Icons.SYSTEM_UPDATE, size=36),
            title=ft.Text(f"تحديث جديد متوفر ({m.get('versionName') or m['version']})"),
            content=ft.Text(m.get("notes") or "اضغط تحديث لتنزيل النسخة الجديدة وتثبيتها."),
            actions=[ft.TextButton("لاحقاً", on_click=later), ft.FilledButton("تحديث", on_click=update)],
        )
    )


def _wrap(main):
    async def wrapped(page):
        result = main(page)
        if inspect.isawaitable(result):
            await result

        async def check():
            m = await asyncio.to_thread(_fetch)
            if m:
                _show(page, m)

        page.run_task(check)

    return wrapped


_original_run = ft.run


def _run(main=None, *args, **kwargs):
    return _original_run(_wrap(main), *args, **kwargs)


ft.run = _run
