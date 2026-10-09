#!/bin/bash
# case-trace.sh — the tester's own lines for one test case of a test-runner log.
#   tmp/mesh-tester-ci/case-trace.sh <run log> "<exact case name>" [all]
# Prints, between the case's "run" and "done" markers, the tester_print/warn
# lines (prefixed with two spaces), the verdict line and any kernel line that
# the splat grep would match, with the colour codes stripped. With a third
# argument "all", every line of the case is printed (hexdumps included).
set -uo pipefail
LOG="${1:?log}"; NAME="${2:?case name}"; ALL="${3:-}"
python3 - "$LOG" "$NAME" "$ALL" <<'PYEOF'
import re, sys
log, name, show_all = sys.argv[1], sys.argv[2], sys.argv[3]
ansi = re.compile(r'\x1b\[[0-9;]*m')
splat = re.compile(r'lockdep|circular|WARNING|BUG:|KASAN|KCSAN|possible|INFO: |deadlock|sleeping function|tx timeout|FAULT_INJECTION|Call Trace|hci0:')
inside = False
for n, raw in enumerate(open(log, errors='replace'), 1):
    line = ansi.sub('', raw.rstrip('\n'))
    if line.startswith(name + ' - '):
        tag = line[len(name) + 3:]
        if tag == 'run':
            inside = True
        print(f'{n}: {line}')
        if tag == 'done':
            inside = False
        continue
    if not inside:
        continue
    if show_all:
        print(f'{n}: {line}')
        continue
    if line.startswith('  ') and not re.match(r'  (hciemu|mgmt|mgmt-alt|mgmt2|bthost|btdev): ', line):
        print(f'{n}: {line}')
    elif splat.search(line) or 'test passed' in line or 'test failed' in line:
        print(f'{n}: {line}')
PYEOF
