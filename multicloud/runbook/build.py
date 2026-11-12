#!/usr/bin/env python3
"""Build the multi-cloud runbook pages from runbook/template.html and the scripts.

Outputs (committed and served as static files; the site itself has no build step):
  multicloud/index.html                         the runbook page: each <pre data-src="path">
                                                in the template is filled with that file
  multicloud/files/index.html                   file browser: every script, env and Terraform file
  multicloud/files/nextgen-multicloud-scripts.zip   all scripts in one download

Script headers (everything up to the '# --- runbook commands' line) are left out of the
runbook page, so the page shows only the commands.

    python multicloud/runbook/build.py           # rebuild everything
    python multicloud/runbook/build.py --check   # fail if any output is out of date
"""
import html
import io
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent          # the multicloud/ folder
TEMPLATE = ROOT / "runbook" / "template.html"
OUT = ROOT / "index.html"
FILES_OUT = ROOT / "files" / "index.html"
ZIP_NAME = "nextgen-multicloud-scripts.zip"
ZIP_OUT = ROOT / "files" / ZIP_NAME
MARKER = "# --- runbook commands"
#         folder   label    tag    tool
CLOUDS = [("aws", "AWS", "aws", "AWS CLI v2"),
          ("azure", "Azure", "az", "Azure CLI"),
          ("gcp", "GCP", "gcp", "gcloud CLI")]
SOURCE_TYPES = (".sh", ".env", ".tf")
TOOLS = ("run-step.sh", "README.md")
PRE = re.compile(r'<pre([^>]*\bdata-src="[^"]+"[^>]*)><code></code></pre>')
esc = lambda s: html.escape(s, quote=True)


def page_text(path):
    """File contents minus the script header."""
    lines = path.read_text(encoding="utf-8").replace("\r\n", "\n").split("\n")
    for i, line in enumerate(lines):
        if line.startswith(MARKER):
            lines = lines[i + 1:]
            break
    return "\n".join(lines).strip("\n")


def source_files(folder):
    d = ROOT / folder
    return sorted(p for p in d.rglob("*") if p.is_file() and p.suffix in SOURCE_TYPES)


# ---------- runbook page ----------
def build_runbook():
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
    unused = [p.relative_to(ROOT).as_posix() for c in CLOUDS for p in source_files(c[0])
              if p.resolve() not in used]
    return page, len(used), unused


# ---------- file browser ----------
FILES_CSS = """
.files-main{padding-block:0 80px;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}
.files-main .wrap{margin:0 auto}
.hero a{color:#fff;text-decoration:underline}
.hero-actions{display:flex;flex-wrap:wrap;gap:10px;margin-top:18px}
.btn{display:inline-flex;align-items:center;gap:6px;padding:9px 16px;border-radius:10px;font-weight:700;font-size:14.5px;
  border:1px solid rgba(255,255,255,.45);background:rgba(255,255,255,.14);color:#fff!important;text-decoration:none!important}
.btn:hover{background:rgba(255,255,255,.24)}
.btn.primary{background:#fff;border-color:#fff;color:#5b21b6!important}
.jump{display:flex;flex-wrap:wrap;gap:8px;margin:24px 0 0}
.jump a{display:inline-flex;align-items:center;gap:8px;padding:6px 12px 6px 6px;border-radius:999px;font-weight:600;color:var(--text);
  background:var(--surface);border:1px solid var(--border)}
.jump a:hover{text-decoration:none;background:var(--surface-2)}
.files-head{display:flex;flex-wrap:wrap;align-items:center;gap:8px 12px;padding-top:16px}
.files-head h2{flex:1 1 220px;margin:0;font-size:21px;font-weight:800}
.files-run{margin:8px 0 12px;color:var(--muted);font-size:14px}
.files-t{min-width:720px}
.files-t td.lines{font-variant-numeric:tabular-nums;color:var(--muted);text-align:right}
.files-t th.lines{text-align:right}
.files-t td.acts{white-space:nowrap;font-size:13.5px}
.files-t td.acts a+a::before{content:"·";color:var(--muted);margin:0 7px}
"""


def describe(folder, path):
    """(step, what it builds, AWS service, anchor on the runbook page) for one file."""
    rel = path.relative_to(ROOT / folder).as_posix()
    if path.suffix == ".env":
        return ("", "Your settings: names, region, account (edit once)", "", "foundation")
    if path.suffix == ".tf":
        return ("18", "Terraform state backend (no lock database needed)", "DynamoDB state locking", "state-locking")
    head = path.read_text(encoding="utf-8").split("\n")[:4]
    m2 = re.match(r"# NextGen runbook - step (\d+) - [^:]+: (.*)", head[1] if len(head) > 1 else "")
    m3 = re.search(r"Replaces AWS: (.*?)\s+\|\s+Page: /multicloud/#(\S+)", head[2] if len(head) > 2 else "")
    if not (m2 and m3):
        return ("", rel, "", "")
    return (m2.group(1), m2.group(2), m3.group(1), m3.group(2))


def repo_slug():
    cfg = ROOT.parent / "assets" / "js" / "config.js"
    m = re.search(r"repo:\s*'([^']+)'", cfg.read_text(encoding="utf-8")) if cfg.is_file() else None
    return m.group(1) if m else ""


def build_files_page(template):
    css = re.search(r"<style>(.*?)</style>", template, re.S).group(1)
    theme_init = re.search(r"<script>/\* follow the DevOps Launchpad theme choice \*/.*?</script>", template).group(0)
    repo = repo_slug()
    gh = f"https://github.com/{repo}/tree/main/multicloud" if repo else ""

    clouds, counts = [], []
    for folder, label, tag, tool in CLOUDS:
        rows = []
        for p in source_files(folder):
            rel = p.relative_to(ROOT).as_posix()
            step, what, aws, anchor = describe(folder, p)
            lines = len(p.read_text(encoding="utf-8").splitlines())
            on_page = f'<a href="../#{esc(anchor)}">On the page</a>' if anchor else ""
            rows.append(
                f'<tr><td class="n">{step}</td>'
                f'<td><a href="../{esc(rel)}"><code>{esc(p.relative_to(ROOT / folder).as_posix())}</code></a></td>'
                f"<td>{esc(what)}</td><td>{esc(aws)}</td><td class=\"lines\">{lines}</td>"
                f'<td class="acts"><a href="../{esc(rel)}">Open</a><a href="../{esc(rel)}" download>Download</a>{on_page}</td></tr>')
        counts.append((folder, label, tag, len(rows)))
        gh_link = f'<a class="ref" href="{gh}/{folder}" target="_blank" rel="noopener">GitHub ↗</a>' if gh else ""
        clouds.append(f"""
  <section class="step" id="{folder}" style="--c:var(--{tag})">
    <div class="files-head"><span class="tag {tag}">{label}</span><h2>{label} scripts ({tool})</h2>{gh_link}</div>
    <p class="files-run">Run one step from the <code>multicloud</code> folder: <code>bash run-step.sh {folder} 05</code>. Settings live in <code>{folder}/nextgen-{folder}.env</code>.</p>
    <div class="tbl"><table class="files-t">
      <thead><tr><th>Step</th><th>File</th><th>What it builds</th><th>AWS service</th><th class="lines">Lines</th><th>Links</th></tr></thead>
      <tbody>{"".join(rows)}</tbody>
    </table></div>
  </section>""")

    tool_rows = "".join(
        f'<tr><td><a href="../{t}"><code>{t}</code></a></td><td>{desc}</td>'
        f'<td class="acts"><a href="../{t}">Open</a><a href="../{t}" download>Download</a></td></tr>'
        for t, desc in (("run-step.sh", "Runs one step for one cloud: <code>bash run-step.sh azure 05</code>"),
                        ("README.md", "How to run steps, change the page and publish")))
    total = sum(c[3] for c in counts)
    jump = "".join(f'<a href="#{f}"><span class="tag {t}">{l}</span>{n} files</a>' for f, l, t, n in counts)
    gh_btn = f'<a class="btn" href="{gh}" target="_blank" rel="noopener">View on GitHub ↗</a>' if gh else ""
    icon = ("<link rel=\"icon\" href=\"data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' "
            "viewBox='0 0 100 100'><text y='.9em' font-size='90'>∞</text></svg>\">")

    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
{theme_init}
<title>Runbook Script Files · DevOps Launchpad</title>
<meta name="description" content="Every AWS, Azure and GCP script behind the NextGen multi-cloud runbook: open, download or run each step.">
{icon}
<style>{css}{FILES_CSS}</style>
</head>
<body>
<!-- Generated by multicloud/runbook/build.py from the files in aws/, azure/ and gcp/. Don't edit by hand. -->
<header class="topbar">
  <a href="../../" class="tb-brand" title="Back to DevOps Launchpad"><span class="logo" aria-hidden="true">∞</span><span>DevOps Launchpad</span></a>
  <span class="crumb">/ <a href="../">Multi-cloud runbook</a> / Script files</span>
  <button id="themeBtn" class="icon-btn" type="button" aria-label="Toggle dark mode" title="Toggle theme">◐</button>
</header>
<main class="files-main">
<div class="wrap">
  <header class="intro hero">
    <p class="eyebrow">NextGen Platform · multi-cloud runbook</p>
    <h1>Runbook script files</h1>
    <p class="lede">Every script behind the runbook, by cloud: {total} files. Open a file to read it in the browser, download it, or jump to its step on the runbook page.</p>
    <div class="hero-actions">
      <a class="btn primary" href="{ZIP_NAME}" download>Download all (.zip)</a>
      <a class="btn" href="../">← Back to the runbook</a>
      {gh_btn}
    </div>
  </header>
  <p class="jump">{jump}<a href="#tools">Tools</a></p>
{"".join(clouds)}
  <section class="step" id="tools">
    <div class="files-head"><h2>Tools</h2></div>
    <div class="tbl" style="margin-top:12px"><table class="files-t" style="min-width:520px">
      <thead><tr><th>File</th><th>What it is</th><th>Links</th></tr></thead>
      <tbody>{tool_rows}</tbody>
    </table></div>
  </section>
</div>
</main>
<script>
document.getElementById('themeBtn').addEventListener('click', function () {{
  var root = document.documentElement;
  var dark = root.getAttribute('data-theme') ? root.getAttribute('data-theme') === 'dark'
    : matchMedia('(prefers-color-scheme: dark)').matches;
  root.setAttribute('data-theme', dark ? 'light' : 'dark');
  try {{ localStorage.setItem('dl-theme', JSON.stringify(root.getAttribute('data-theme'))); }} catch (e) {{}}
}});
</script>
</body>
</html>
"""


# ---------- zip of all scripts ----------
def zip_members():
    paths = [p for c in CLOUDS for p in source_files(c[0])] + [ROOT / t for t in TOOLS]
    return [("nextgen-multicloud/" + p.relative_to(ROOT).as_posix(), p.read_bytes()) for p in paths]


def build_zip(members):
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as z:
        for name, data in members:
            info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))   # fixed date: same input, same zip
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (0o755 if name.endswith(".sh") else 0o644) << 16
            z.writestr(info, data)
    return buf.getvalue()


def zip_is_current(members):
    if not ZIP_OUT.is_file():
        return False
    with zipfile.ZipFile(ZIP_OUT) as z:
        return sorted((n, z.read(n)) for n in z.namelist()) == sorted(members)


def write(path, text):
    path.parent.mkdir(exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def main():
    page, count, unused = build_runbook()
    files_page = build_files_page(TEMPLATE.read_text(encoding="utf-8"))
    members = zip_members()

    if "--check" in sys.argv:
        stale = [name for name, ok in (
            ("multicloud/index.html", OUT.is_file() and OUT.read_text(encoding="utf-8") == page),
            ("multicloud/files/index.html", FILES_OUT.is_file() and FILES_OUT.read_text(encoding="utf-8") == files_page),
            (f"multicloud/files/{ZIP_NAME}", zip_is_current(members))) if not ok]
        if stale:
            sys.exit("Out of date: " + ", ".join(stale) + ". Run  python multicloud/runbook/build.py  and commit the result.")
        print(f"Runbook page, file browser and zip are up to date ({count} files on the page, {len(members)} in the zip)")
        return

    write(OUT, page)
    write(FILES_OUT, files_page)
    if not zip_is_current(members):
        ZIP_OUT.write_bytes(build_zip(members))
    print(f"Built multicloud/index.html ({count} files), multicloud/files/index.html and files/{ZIP_NAME} ({len(members)} files)")
    if unused:
        print("Not shown on the runbook page (add a <pre data-src> to the template):", ", ".join(unused))


if __name__ == "__main__":
    main()
