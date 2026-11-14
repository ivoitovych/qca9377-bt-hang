import re
D = "/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle/l2runs/"
def load(f):
    out = {}
    for l in open(f, errors="replace"):
        m = re.match(r"^(PASSED|FAILED|SKIPPED|ERROR) (\S+)", l)
        if m:
            name = m.group(2).split("::")[-1]
            name = re.sub(r"\[.*", "", name)
            out[name] = m.group(1)
    return out
b = load(D + "base-l2.stdout.log"); n = load(D + "bundle-l2.stdout.log")
print("base:", len(b), {k: list(b.values()).count(k) for k in set(b.values())})
print("bundle:", len(n), {k: list(n.values()).count(k) for k in set(n.values())})
ch = [(k, b.get(k), n.get(k)) for k in sorted(set(b) | set(n)) if b.get(k) != n.get(k)]
print("changed outcomes:", len(ch))
for k, x, y in ch:
    print("  %-60s %s -> %s" % (k, x, y))
print("unchanged non-pass:", [(k, b[k]) for k in sorted(b) if b[k] == n.get(k) and b[k] != "PASSED"])
