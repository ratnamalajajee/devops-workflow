#!/usr/bin/env python3
"""Build multicloud/index.html (served at /multicloud/) from runbook/template.html
and the step scripts in aws/, azure/ and gcp/.

Every <pre data-src="path"> in the template is filled with that file's contents.
Script headers (everything up to the '# --- runbook commands' line) are left out,
so the page shows only the commands. The site itself still has no build step:
the built index.html is committed and served as a static file.

    python multicloud/runbook/build.py           # rebuild the page
    python multicloud/runbook/build.py --check   # fail if index.html is out of date
"""
import html
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent          # the multicloud/ folder
TEMPLATE = ROOT / "runbook" / "template.html"
OUT = ROOT / "index.html"
MARKER = "# --- runbook commands"
SOURCE_DIRS = ("aws", "azure", "gcp")
SOURCE_TYPES = (".sh", ".env", ".tf")
PRE = re.compile(r'<pre([^>]*\bdata-src="[^"]+"[^>]*)><code></code></pre>')


def page_text(path):
    """File contents minus the script header."""
    lines = path.read_text(encoding="utf-8").replace("\r\n", "\n").split("\n")
    for i, line in enumerate(lines):
        if line.startswith(MARKER):
            lines = lines[i + 1:]
            break
    return "\n".join(lines).strip("\n")


def build():
    template = TEMPLATE.read_text(encoding="utf-8")
    used, missing = set(), []

    def fill(match):
        attrs = match.group(1)
        src = re.search(r'data-src="([^"]+)"', attrs).group(1)
        cap = re.search(r'data-cap="([^"]*)"', attrs)
        path = ROOT / src
        if not path.is_file():
            missing.append(src)
            return match.group(0)
        used.add(path.resolve())
        caption = f"{src} · {cap.group(1)}" if cap and cap.group(1) else src
        return (f'<pre data-src="{src}" data-cap="{caption}"><code>'
                f"{html.escape(page_text(path), quote=False)}</code></pre>")

    page = PRE.sub(fill, template)
    if missing:
        sys.exit("Missing files referenced by the template: " + ", ".join(missing))

    unused = sorted(
        p.relative_to(ROOT).as_posix()
        for d in SOURCE_DIRS for p in (ROOT / d).rglob("*")
        if p.is_file() and p.suffix in SOURCE_TYPES and p.resolve() not in used)
    return page, len(used), unused


def main():
    page, count, unused = build()
    if "--check" in sys.argv:
        current = OUT.read_text(encoding="utf-8") if OUT.is_file() else ""
        if current != page:
            sys.exit("multicloud/index.html is out of date: run  python multicloud/runbook/build.py  and commit it")
        print(f"multicloud/index.html is up to date ({count} files)")
        return
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(page)
    print(f"Built multicloud/index.html from {count} files")
    if unused:
        print("Not shown on the page (add a <pre data-src> to the template):", ", ".join(unused))


if __name__ == "__main__":
    main()
