#!/usr/bin/env python3
# compare-tester-verdicts.py <log A> <log B> - the per-case verdict lines of two
# tester runs (test-runner logs, colour codes stripped) side by side: totals,
# then every case whose verdict differs, then whether the failing sets are
# identical.
import re, sys
ansi = re.compile(r'\x1b\[[0-9;]*m')
line_re = re.compile(r'^(.*?)\s+(Passed|Failed|Timed out|Not Run)\s+[0-9.]+ seconds\s*$')
# A run that was stopped before its summary table still has one progress
# line per finished case: "<name> - test passed|failed|timed out|not run".
progress_re = re.compile(r'^(.*?) - test (passed|failed|timed out|not run)\s*$')
progress_word = {'passed': 'Passed', 'failed': 'Failed',
                 'timed out': 'Timed out', 'not run': 'Not Run'}

def verdicts(path):
    v, p = {}, {}
    for raw in open(path, errors='replace'):
        line = ansi.sub('', raw.rstrip('\n'))
        m = line_re.match(line)
        if m:
            v[m.group(1).strip()] = m.group(2)
            continue
        m = progress_re.match(line)
        if m:
            p[m.group(1).strip()] = progress_word[m.group(2)]
    if not v and p:
        print('%s: no summary table; using %d progress lines' % (path, len(p)))
        return p
    return v

a, b = verdicts(sys.argv[1]), verdicts(sys.argv[2])
for name, v in (('A', a), ('B', b)):
    counts = {}
    for x in v.values():
        counts[x] = counts.get(x, 0) + 1
    print('%s: %d cases %s' % (name, len(v), ' '.join('%s=%d' % kv for kv in sorted(counts.items()))))
diff = [(n, a.get(n, '-'), b.get(n, '-')) for n in sorted(set(a) | set(b)) if a.get(n) != b.get(n)]
print('cases with different verdicts: %d' % len(diff))
for n, x, y in diff:
    print('  %-55s A=%-10s B=%s' % (n, x, y))
fa = {n for n, x in a.items() if x != 'Passed'}
fb = {n for n, x in b.items() if x != 'Passed'}
print('not-passed sets identical: %s (A %d, B %d)' % (fa == fb, len(fa), len(fb)))
