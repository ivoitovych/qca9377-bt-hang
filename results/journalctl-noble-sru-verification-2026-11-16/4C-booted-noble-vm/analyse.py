import re, sys, collections
ph, n = sys.argv[1], int(sys.argv[2])
for kind, path in (("full read", sys.argv[3]), ("journalctl -f", sys.argv[4])):
    seen = collections.defaultdict(list)
    for line in open(path, errors="replace"):
        m = re.match(r"MARK (\w+) (\d{6}) ", line)
        if m:
            seen[m.group(1)].append(int(m.group(2)))
    for tag in (f"sys{ph}", f"usr{ph}"):
        v = seen.get(tag, [])
        s = set(v)
        missing = n - len(s & set(range(n)))
        dup = len(v) - len(s)
        order = sum(1 for a, b in zip(v, v[1:]) if b < a)
        print(f"RESULT {ph} {kind} {tag}: expected {n}, lines {len(v)}, missing {missing}, duplicates {dup}, out-of-order steps {order}")
