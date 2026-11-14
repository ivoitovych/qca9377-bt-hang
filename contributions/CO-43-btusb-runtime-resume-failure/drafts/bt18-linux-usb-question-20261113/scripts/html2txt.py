#!/usr/bin/env python3
"""Print the text of a hypermail/mail-archive HTML page, with links listed.

Usage: html2txt.py <file.html> [--links]
"""
import html
import re
import sys


def main():
    path = sys.argv[1]
    show_links = "--links" in sys.argv[2:]
    with open(path, "rb") as f:
        raw = f.read().decode("utf-8", "replace")
    links = re.findall(r'<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>', raw, re.S | re.I)
    text = re.sub(r"(?is)<(script|style).*?</\1>", "", raw)
    text = re.sub(r"(?i)<br\s*/?>", "\n", text)
    text = re.sub(r"(?i)</(p|div|li|tr|h\d|pre)>", "\n", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = html.unescape(text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    if "--trim" in sys.argv[2:]:
        # mail-archive.com: body ends at the unsubscribe footer or nav
        for marker in ("\n--\nTo unsubscribe", "\nPrevious message\n", "\nNext message:"):
            cut = text.find(marker, 200)
            if cut > 0:
                text = text[:cut]
        text = re.sub(r"\n\s*\n", "\n", text)
        # keep first-level quotes only; drop deeper ones
        text = "\n".join(l for l in text.split("\n")
                         if not re.match(r"\s*>\s*>", l))
    print(text)
    if show_links:
        print("---- links ----")
        for href, label in links:
            label = re.sub(r"<[^>]+>", "", label).strip()
            print(href, "|", html.unescape(label)[:100])


if __name__ == "__main__":
    main()
