import re
import sys
from html.parser import HTMLParser

# usage: html2text.py IN.html OUT.txt  (keeps the <main>/<article> text, one block per line)


class P(HTMLParser):
    def __init__(self):
        super().__init__()
        self.out = []
        self.skip = 0

    def handle_starttag(self, tag, attrs):
        if tag in ('script', 'style', 'nav'):
            self.skip += 1
        if tag in ('p', 'li', 'h1', 'h2', 'h3', 'h4', 'pre', 'div', 'br'):
            self.out.append('\n')
        if tag == 'li':
            self.out.append('- ')

    def handle_endtag(self, tag):
        if tag in ('script', 'style', 'nav'):
            self.skip -= 1

    def handle_data(self, d):
        if not self.skip:
            self.out.append(d)


p = P()
p.feed(open(sys.argv[1], encoding='utf-8').read())
t = re.sub(r'\n\s*\n+', '\n', ''.join(p.out))
open(sys.argv[2], 'w').write(t)
