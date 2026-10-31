"""Fast static check for a generated Flet app, run before the slow APK build.

Usage: python check_python.py path/to/main.py
Prints problems and exits 1 when it finds any: syntax errors, or `ft.Something`
that does not exist in the installed Flet version (e.g. the old pre-1.0 API).
"""
import ast
import inspect
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


def check(source):
    try:
        tree = ast.parse(source)
    except SyntaxError as e:
        return [f"SyntaxError line {e.lineno}: {e.msg}"]

    aliases = {a.asname or "flet" for n in ast.walk(tree) if isinstance(n, ast.Import)
               for a in n.names if a.name == "flet"}
    if not aliases:
        return ["main.py does not import flet (expected `import flet as ft`)"]

    # Only look at the outermost attribute of each chain (ft.Colors.BLUE, not ft.Colors too).
    inner = {id(c) for n in ast.walk(tree) if isinstance(n, ast.Attribute)
             for c in ast.iter_child_nodes(n) if isinstance(c, ast.Attribute)}

    import flet

    problems, seen = [], set()
    for node in ast.walk(tree):
        if not isinstance(node, ast.Attribute) or id(node) in inner:
            continue
        chain = attr_chain(node)
        if not chain or chain[0] not in aliases:
            continue
        obj = flet
        for i, part in enumerate(chain[1:], start=1):
            # Only modules and classes are checked; instance attributes are left alone.
            if not (inspect.ismodule(obj) or inspect.isclass(obj)):
                break
            if not hasattr(obj, part):
                name = ".".join(chain[: i + 1])
                if name not in seen:
                    seen.add(name)
                    problems.append(f"line {node.lineno}: `{name}` does not exist in Flet {flet.__version__}")
                break
            obj = getattr(obj, part)
    return problems


def main():
    problems = check(Path(sys.argv[1]).read_text(encoding="utf-8"))
    if problems:
        print("error: Flet check failed:")
        for p in problems:
            print(f"error: {p}")
        sys.exit(1)
    print("Flet check passed")


if __name__ == "__main__":
    main()
