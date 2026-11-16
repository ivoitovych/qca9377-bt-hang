#!/usr/bin/env python3
"""html2text.py FILE : visible text of an HTML file, one block per line (standard library only)."""
import sys
from html.parser import HTMLParser


class P(HTMLParser):
    def __init__(self):
        super().__init__()
        self.skip = 0
        self.out = []

    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style", "nav", "footer", "head"):
            self.skip += 1
        if tag in ("p", "li", "h1", "h2", "h3", "h4", "br", "tr", "div", "pre", "dt", "dd"):
            self.out.append("\n")

    def handle_endtag(self, tag):
        if tag in ("script", "style", "nav", "footer", "head"):
            self.skip = max(0, self.skip - 1)
        if tag in ("p", "li", "h1", "h2", "h3", "h4", "tr", "div", "pre"):
            self.out.append("\n")

    def handle_data(self, d):
        if not self.skip:
            self.out.append(d)


p = P()
p.feed(open(sys.argv[1], errors="replace").read())
text = "".join(p.out)
lines = [" ".join(l.split()) for l in text.split("\n")]
print("\n".join(l for l in lines if l))
