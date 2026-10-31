"""Fast static check for a generated Flet app, run before the slow APK build.

Usage: python check_python.py [--fix] path/to/main.py
Prints problems and exits 1 when it finds any: syntax errors, or `ft.Something`
that does not exist in the installed Flet version (e.g. the old pre-1.0 API).
Each problem comes with the correct name when one can be found. With --fix,
unambiguous corrections (e.g. `ft.padding.only` -> `ft.Padding.only`) are
written back to the file first, so only real problems are left for the AI.
"""
import ast
import difflib
import inspect
import re
import sys
from pathlib import Path


def attr_chain(node):
    parts = []
    while isinstance(node, ast.Attribute):
        parts.append(node.attr)
        node = node.value
    if isinstance(node, ast.Name):
        parts.append(node.id)
        return list(reversed(parts))
    return None


# Names Flet 1.0 removed, with their replacement.
RENAMED = {"ElevatedButton": "Button"}


def checkable(obj):
    # Modules, classes, and lazy proxies such as ft.Icons.
    return inspect.ismodule(obj) or inspect.isclass(obj) or type(obj).__name__.endswith("Proxy")


def camel(name):
    return "".join(p[:1].upper() + p[1:] for p in name.split("_"))


def suggest(flet, chain, i, parent):
    """Return (correct dotted name, sure) for chain[i] missing on parent, or (None, False)."""
    part = chain[i]
    if i == 1 and part in RENAMED:
        return ".".join([chain[0], RENAMED[part]] + chain[2:]), True
    # Flet 1.0 moved helpers from modules to classes: ft.padding.only -> ft.Padding.only,
    # ft.alignment.center -> ft.Alignment.CENTER, ft.border_radius.all -> ft.BorderRadius.all.
    if inspect.ismodule(parent) and i == 2:
        new = camel(chain[1])
        cls = getattr(flet, new, None)
        if cls is not None and checkable(cls):
            for name in (part, part.upper(), part.lower()):
                if hasattr(cls, name):
                    return ".".join([chain[0], new, name] + chain[i + 1:]), True
    names = [n for n in dir(parent) if not n.startswith("_")]
    by_case = [n for n in names if n.lower() == part.lower()]
    if len(by_case) == 1:
        return ".".join(chain[:i] + by_case + chain[i + 1:]), True
    close = difflib.get_close_matches(part, names, n=2, cutoff=0.6)
    if not close:
        close = [n for n in names if part.upper() in n.upper()][:2]
    if close:
        sure = len(close) == 1 and difflib.SequenceMatcher(None, part, close[0]).ratio() >= 0.75
        return ".".join(chain[:i] + [close[0]] + chain[i + 1:]), sure
    return None, False


def check(source):
    """Return a list of (line, wrong dotted name, suggestion or None, sure)."""
    tree = ast.parse(source)
    aliases = {a.asname or "flet" for n in ast.walk(tree) if isinstance(n, ast.Import)
               for a in n.names if a.name == "flet"}
    if not aliases:
        return [(1, "import flet", "import flet as ft", False)]

    # Only look at the outermost attribute of each chain (ft.Colors.BLUE, not ft.Colors too).
    inner = {id(c) for n in ast.walk(tree) if isinstance(n, ast.Attribute)
             for c in ast.iter_child_nodes(n) if isinstance(c, ast.Attribute)}

    import flet

    problems = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Attribute) or id(node) in inner:
            continue
        chain = attr_chain(node)
        if not chain or chain[0] not in aliases:
            continue
        obj = flet
        for i, part in enumerate(chain[1:], start=1):
            # Only modules, classes and proxies are checked; instance attributes are left alone.
            if not checkable(obj):
                break
            if not hasattr(obj, part):
                fixed, sure = suggest(flet, chain, i, obj)
                problems.append((node.lineno, ".".join(chain[: i + 1]), fixed, sure, ".".join(chain)))
                break
            obj = getattr(obj, part)
    return problems


def apply_fixes(path, source, problems):
    lines = source.split("\n")
    changed = 0
    for lineno, _, fixed, sure, full in problems:
        if not (fixed and sure):
            continue
        pattern = r"(?<![\w.])" + re.escape(full) + r"(?!\w)"
        new = re.sub(pattern, fixed, lines[lineno - 1])
        if new != lines[lineno - 1]:
            lines[lineno - 1] = new
            changed += 1
    if changed:
        path.write_text("\n".join(lines), encoding="utf-8")
    return changed


def main():
    args = sys.argv[1:]
    fix = "--fix" in args
    path = Path([a for a in args if a != "--fix"][0])
    source = path.read_text(encoding="utf-8")
    try:
        problems = check(source)
        if fix and problems:
            changed = apply_fixes(path, source, problems)
            if changed:
                print(f"Auto-fixed {changed} line(s) to the Flet 1.x API")
                source = path.read_text(encoding="utf-8")
                problems = check(source)
    except SyntaxError as e:
        print("error: Flet check failed:")
        print(f"error: SyntaxError line {e.lineno}: {e.msg}")
        sys.exit(1)

    if problems:
        import flet
        print("error: Flet check failed:")
        seen = set()
        for lineno, wrong, fixed, _, _ in problems:
            if wrong in seen:
                continue
            seen.add(wrong)
            hint = f" (use `{fixed}`)" if fixed else ""
            print(f"error: line {lineno}: `{wrong}` does not exist in Flet {flet.__version__}{hint}")
        sys.exit(1)
    print("Flet check passed")


if __name__ == "__main__":
    main()
