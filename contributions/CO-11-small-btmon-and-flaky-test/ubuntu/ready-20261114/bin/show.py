import re, sys, html
F = "/root/exp/agent-work/lane5-status-stable-20261114/task4/fetched/"
n = sys.argv[1]; lim = int(sys.argv[2]) if len(sys.argv) > 2 else 3000
t = open(F + n, errors="replace").read()
if n.endswith(".html"):
    t = re.sub(r"(?s)<(script|style).*?</\1>", "", t)
    t = re.sub(r"<[^>]+>", " ", t)
    t = html.unescape(re.sub(r"[ \t]+", " ", t))
    t = re.sub(r"\n\s*\n+", "\n", t)
print(t[:lim])
