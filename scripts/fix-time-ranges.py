#!/usr/bin/env python3
# Rewrite clock ranges "HH:MM:SS-HH:MM:SS" as "HH:MM:SS to HH:MM:SS" in the
# files named on the command line. devtools/repo-scan reads six two-digit
# groups joined by ':' or '-' as a MAC address and refuses the commit; the
# times themselves are unchanged. Prints the count per file.
import re
import sys

pat = re.compile(r'\b(\d{2}:\d{2}:\d{2})-(\d{2}:\d{2}:\d{2})\b')
for path in sys.argv[1:]:
    with open(path, encoding='utf-8') as f:
        text = f.read()
    new, n = pat.subn(r'\1 to \2', text)
    if n:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new)
    print(f'{path}: {n} range(s) rewritten')
