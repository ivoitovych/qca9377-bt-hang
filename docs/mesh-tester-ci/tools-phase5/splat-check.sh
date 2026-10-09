#!/bin/bash
# splat-check.sh <run log>... - the kernel report headers in test-runner logs.
# Counts the lines that START a kernel report (not the frames inside the
# FAULT_INJECTION stack dumps, which mention lockdep_* functions), per pattern,
# and the fault-injection dumps separately. Prints "clean" when no report
# header is found. Colour codes are stripped first.
set -u
for log in "$@"; do
	echo "== $log"
	python3 - "$log" <<'PYEOF'
import re, sys
ansi = re.compile(r'\x1b\[[0-9;]*m')
pats = {
    'BUG:': re.compile(r'\bBUG: '),
    'WARNING:': re.compile(r'\bWARNING: '),
    'KASAN': re.compile(r'BUG: KASAN|KASAN: '),
    'KCSAN': re.compile(r'BUG: KCSAN|KCSAN: '),
    'lockdep circular': re.compile(r'possible circular locking dependency'),
    'lockdep recursive': re.compile(r'possible recursive locking'),
    'lockdep other': re.compile(r'inconsistent lock state|lock held when returning|bad unlock balance|suspicious RCU usage'),
    'hung task': re.compile(r'INFO: task .* blocked'),
    'sleep in atomic': re.compile(r'sleeping function called from invalid context'),
    'Oops/GPF': re.compile(r'Oops:|general protection fault'),
    'tx timeout': re.compile(r'tx timeout'),
    'memory leak': re.compile(r'unreferenced object'),
}
counts = {k: 0 for k in pats}
first = {}
fi = 0
for n, raw in enumerate(open(sys.argv[1], errors='replace'), 1):
    line = ansi.sub('', raw)
    if 'FAULT_INJECTION: forcing a failure' in line:
        fi += 1
    for k, p in pats.items():
        if p.search(line):
            counts[k] += 1
            first.setdefault(k, (n, line.strip()[:120]))
total = sum(counts.values())
print('  fault-injection dumps: %d' % fi)
if not total:
    print('  report headers: clean (none of: %s)' % ', '.join(pats))
for k, c in counts.items():
    if c:
        print('  %s: %d  first at line %d: %s' % (k, c, first[k][0], first[k][1]))
PYEOF
done
