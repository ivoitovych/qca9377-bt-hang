#!/usr/bin/env python3
"""Search lkml.iu.edu hypermail subject indexes for a regex.

Usage: hm-search.py <regex> <week>...   (week like 2609.2)
Prints: week, message file, the link label (author: subject).
Index pages are cached in threads/hm-index/<week>-subject.html.
"""
import html
import os
import re
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(os.path.dirname(HERE), "threads", "hm-index")


def get(week):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, week + "-subject.html")
    if not os.path.exists(path):
        url = "https://lkml.iu.edu/hypermail/linux/kernel/%s/subject.html" % week
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=120) as r:
            data = r.read()
        with open(path, "wb") as f:
            f.write(data)
    with open(path, "rb") as f:
        return f.read().decode("utf-8", "replace")


def main():
    pat = re.compile(sys.argv[1], re.I)
    for week in sys.argv[2:]:
        try:
            raw = get(week)
        except Exception as e:
            print(week, "FAILED", e)
            continue
        # entries: <li><strong>subject</strong> then lines
        # <ul><li><a name="N" href="N.html">author</a><em>(date)</em></ul>
        for block in raw.split("<li><strong>")[1:]:
            subj, _, body = block.partition("</strong>")
            subj = html.unescape(re.sub(r"<[^>]+>", "", subj)).strip()
            if not pat.search(subj):
                continue
            for m in re.finditer(r'href="(\d+\.html)">(.*?)</a><em>(.*?)</em>', body):
                print(week, m.group(1), "|", subj, "|",
                      html.unescape(m.group(2)), html.unescape(m.group(3)))


if __name__ == "__main__":
    main()
