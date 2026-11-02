#!/usr/bin/env python3
"""Render followups.md to followups.html (same styling as the review document).

  followups-build.py
"""
import re
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
md = (HERE / "followups.md").read_text(encoding="utf-8")
bad = [(re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+"), "address"), (re.compile(r"https?://"), "URL"),
       (re.compile(r"compaction", re.I), "word"), (re.compile(r"/root/|/tmp/"), "path")]
for n, line in enumerate(md.splitlines(), 1):
    for rx, what in bad:
        if rx.search(line):
            print(f"CHECK {what}: line {n}: {line.strip()[:100]}")
html = subprocess.run(
    ["pandoc", "-f", "markdown-smart", "-t", "html5", "-s", "--toc", "--toc-depth=2",
     "--include-in-header", str(HERE / "header.html"), "--metadata", "lang=en",
     "--metadata", "pagetitle=Review Follow-ups"],
    input=md, capture_output=True, text=True, check=True).stdout
(HERE / "followups.html").write_text(html, encoding="utf-8")
print("wrote", HERE / "followups.html")
