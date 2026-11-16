#!/usr/bin/env python3
"""move-brief-block.py <first> <last> <heading> <replacement-file>

Move lines <first>..<last> (1-based, inclusive) of BRIEF.md verbatim to the end of HISTORY.md
under "## <heading>", and put the contents of <replacement-file> in their place in BRIEF.md.
Prints the first and last moved line, so the range can be checked. The project's practice:
hand-off blocks are replaced, never stacked, and the old text is kept verbatim in HISTORY.md."""
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent   # this checkout, wherever it is
if len(sys.argv) != 5:
    sys.exit(__doc__)
first, last, heading, repl = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3], Path(sys.argv[4])
brief = (root / "BRIEF.md").read_text().split("\n")
history = root / "HISTORY.md"
# The range is checked BEFORE anything is written: HISTORY.md is appended to
# first, and a range outside the file would append a wrong or empty block to it
# and then rewrite BRIEF.md.
if not (1 <= first <= last <= len(brief)):
    sys.exit(f"range {first}..{last} is outside BRIEF.md (1..{len(brief)}); nothing was written")
if not repl.is_file() or not repl.read_text().strip():
    sys.exit(f"{repl} is missing or empty; nothing was written")
block = brief[first - 1:last]
print("first moved:", block[0][:100])
print("last moved: ", block[-1][:100])
text = history.read_text().rstrip("\n")
history.write_text(text + "\n\n## " + heading + "\n\n" + "\n".join(block) + "\n")
new = repl.read_text().rstrip("\n").split("\n")
(root / "BRIEF.md").write_text("\n".join(brief[:first - 1] + new + brief[last:]))
print(f"moved {len(block)} lines; inserted {len(new)}")
