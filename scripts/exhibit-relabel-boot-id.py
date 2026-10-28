#!/usr/bin/env python3
"""Relabel the pre-2026-10-02 exhibit provenance field `| boot id |`.

That field was the machine's boot at capture time (tools/bt-exhibit, comment at
"EVIDENCE BOOTS ARE NOT THE CAPTURE BOOT"), not the boot the evidence comes
from. Rewrite it the way bt-exhibit now writes it:

    | capture boot id | `xxxxxxxx` |
    | evidence boot ids | `aaaaaaaa, bbbbbbbb` |     (32-hex ids the command names)
    | evidence boot ids | none named by the command (...) |

Each old row is matched with the `$ ` command lines between the previous old row
(or the top of the file) and itself, so an exhibit with two captures gets two
answers. Only plain rows (an id and nothing else) are the tool's: a row with a
note after the id was written by hand and already says which boot it means
(EX-029, 034, 038, 040, 042, 043), so it is left alone. Only those rows change.
Usage: exhibit-relabel-boot-id.py [--write] FILE...   (without --write: report only)
Run once on 2026-10-29 over the 46 exhibits with a plain row (CO-25 log.md).
"""
import re
import sys

ROW = re.compile(r"^\| boot id \| `([0-9a-f]{8})`() \|$", re.M)
NONE = ("| evidence boot ids | none named by the command (it selects by index "
        "or not by boot) — see the window above |")


def evidence_boots(segment):
    seen = []
    for line in segment.splitlines():
        if not line.startswith("$ "):
            continue
        for b in re.findall(r"\b[0-9a-f]{32}\b", line):
            if b[:8] not in seen:
                seen.append(b[:8])
    return seen


def main(argv):
    write = "--write" in argv
    files = [a for a in argv if a != "--write"]
    rc = 0
    for path in files:
        with open(path, encoding="utf-8") as f:
            text = f.read()
        rows = list(ROW.finditer(text))
        if not rows:
            print(f"SKIP {path}: no old boot id row")
            rc = 1
            continue
        out, start = [], 0
        for m in rows:
            boots = evidence_boots(text[start:m.start()])
            ev = (f"| evidence boot ids | `{', '.join(boots)}` |" if boots else NONE)
            out.append(text[start:m.start()])
            out.append(f"| capture boot id | `{m.group(1)}`{m.group(2)} |\n{ev}")
            print(f"{path}: capture {m.group(1)}{m.group(2)}; "
                  f"evidence {', '.join(boots) or 'none named'}")
            start = m.end()
        out.append(text[start:])
        if write:
            with open(path, "w", encoding="utf-8") as f:
                f.write("".join(out))
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
