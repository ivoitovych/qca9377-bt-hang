#!/usr/bin/env python3
"""Assemble the review document from its section files and render it.

  build.py            writes review-package.md and index.html in this folder

Sections: 00-front.md, then every "## CO-..." item from the section files,
in the order of ORDER below. Missing items are reported, not invented.
"""
import html
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SECTIONS = Path("/root/exp/agent-work/review-doc-20261102")
SECTION_FILES = ["kernel-sco.md", "kernel-mesh.md", "stable-qca.md", "bluez-ubuntu.md", "audio.md"]
ORDER = ["CO-25", "CO-04", "CO-38", "CO-12", "CO-05", "CO-02", "CO-21", "CO-30",
         "CO-35", "CO-22", "CO-23", "CO-03", "CO-11", "CO-19", "CO-36", "CO-32"]

# Checks on the assembled text: none of these may appear.
FORBIDDEN = [
    (re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+"), "email address or message id"),
    (re.compile(r"https?://", re.I), "URL"),
    (re.compile(r"\b(?:[0-9A-F]{2}:){5}[0-9A-F]{2}\b", re.I), "device address"),
    (re.compile(r"compaction", re.I), "forbidden word"),
    (re.compile(r"\b(claude|anthropic|chatgpt|openai|gemini|grok|copilot|llm|\bAI\b)", re.I), "assistant name"),
    (re.compile(r"(?<!-)\b(family|household|kitchen)\b", re.I), "wording"),
    (re.compile(r"\b(agent|subagent|work area|agent-work)\b", re.I), "internal process"),
    (re.compile(r"/root/|/tmp/|contributions/|\.\./", re.I), "local path"),
]


def split_items(text):
    """Return {CO-id: block} for every '## CO-..' heading in text."""
    items = {}
    parts = re.split(r"(?m)^(?=## CO-)", text)
    for part in parts:
        m = re.match(r"## (CO-\d+)", part)
        if m:
            items.setdefault(m.group(1), part.rstrip() + "\n")
    return items


def main():
    items = {}
    for name in SECTION_FILES:
        p = SECTIONS / name
        if not p.exists():
            print(f"missing section file: {name}")
            continue
        for k, v in split_items(p.read_text(encoding="utf-8")).items():
            if k in items:
                print(f"duplicate item {k} in {name}")
            items[k] = v
    out = [(HERE / "00-front.md").read_text(encoding="utf-8").rstrip() + "\n"]
    out.append("\n# The items in detail\n")
    for k in ORDER:
        if k in items:
            out.append("\n" + items[k])
        else:
            print(f"item not found: {k}")
    extra = sorted(set(items) - set(ORDER))
    for k in extra:
        print(f"item not in ORDER (appended): {k}")
        out.append("\n" + items[k])
    md = "".join(out)
    # Outside readers do not know "the operator": he is the submitter.
    for old, new in (("The operator's", "The submitter's"), ("the operator's", "the submitter's"),
                     ("The operator", "The submitter"), ("the operator", "the submitter")):
        md = md.replace(old, new)
    (HERE / "review-package.md").write_text(md, encoding="utf-8")

    problems = 0
    for lineno, line in enumerate(md.splitlines(), 1):
        for rx, what in FORBIDDEN:
            for m in rx.finditer(line):
                problems += 1
                print(f"CHECK {what}: line {lineno}: {m.group(0)!r} :: {line.strip()[:120]}")
    print(f"checks: {problems} finding(s); {len(md.splitlines())} lines; {len(md)} chars")

    body = subprocess.run(
        ["pandoc", "-f", "markdown-smart-implicit_figures", "-t", "html5", "-s", "--toc", "--toc-depth=2",
         "--no-highlight", "--include-in-header", str(HERE / "header.html"),
         "--metadata", "lang=en", "--metadata", "pagetitle=Bluetooth Submissions Review"],
        input=md, capture_output=True, text=True, check=True).stdout

    raw_json = json.dumps(md).replace("</", "<\\/")
    toolbar = (
        '<div class="toolbar">'
        '<button type="button" id="copy-md">Copy as Markdown</button>'
        '<button type="button" id="toggle-raw">Show plain Markdown</button>'
        '<span id="copy-status" aria-live="polite"></span></div>'
        '<div id="raw-view"><pre><code id="raw-code"></code></pre></div>'
    )
    script = """<script>
(function () {
  var RAW = %s;
  document.getElementById('raw-code').textContent = RAW;
  var status = document.getElementById('copy-status');
  document.getElementById('copy-md').addEventListener('click', function () {
    function fallback() {
      var ta = document.createElement('textarea'); ta.value = RAW; document.body.appendChild(ta);
      ta.select(); var ok = false; try { ok = document.execCommand('copy'); } catch (e) {}
      document.body.removeChild(ta); status.textContent = ok ? 'Copied.' : 'Copy refused; use "Show plain Markdown" and select it.';
    }
    try {
      navigator.clipboard.writeText(RAW).then(function () { status.textContent = 'Copied.'; }, fallback);
    } catch (e) { fallback(); }
  });
  var shown = false;
  document.getElementById('toggle-raw').addEventListener('click', function () {
    shown = !shown;
    document.getElementById('raw-view').style.display = shown ? 'block' : 'none';
    document.getElementById('rendered').style.display = shown ? 'none' : 'block';
    this.textContent = shown ? 'Show formatted' : 'Show plain Markdown';
  });
  document.querySelectorAll('#rendered pre code').forEach(function (el) {
    var cls = el.parentNode.className + ' ' + el.className;
    if (!/diff/.test(cls)) return;
    var lines = el.textContent.split('\\n');
    el.textContent = '';
    lines.forEach(function (ln, i) {
      var span = document.createElement('span');
      if (/^\\+(?!\\+\\+ )/.test(ln)) span.className = 'l-add';
      else if (/^-(?!-- )/.test(ln)) span.className = 'l-del';
      else if (/^@@/.test(ln)) span.className = 'l-hunk';
      span.textContent = ln + (i < lines.length - 1 ? '\\n' : '');
      el.appendChild(span);
    });
  });
})();
</script>""" % raw_json

    m = re.search(r"(?s)(<body>)(.*?)(</body>)", body)
    if not m:
        sys.exit("pandoc output has no body")
    inner = m.group(2)
    hdr = re.search(r"(?s)<header id=\"title-block-header\">.*?</header>", inner)
    head_html = hdr.group(0) if hdr else ""
    rest = inner.replace(head_html, "", 1)
    new_body = head_html + toolbar + '<div id="rendered">' + rest + "</div>" + script
    page = body[:m.start(2)] + new_body + body[m.end(2):]
    page = page.replace("<!DOCTYPE html>", "<!DOCTYPE html>", 1)
    if not page.lstrip().lower().startswith("<!doctype html>"):
        page = "<!DOCTYPE html>\n" + page
    (HERE / "index.html").write_text(page, encoding="utf-8")
    print("wrote", HERE / "review-package.md", "and", HERE / "index.html")


if __name__ == "__main__":
    main()
