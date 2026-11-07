#!/usr/bin/env python3
"""move-brief-block.py <first> <last> <heading> <replacement-file>

Move lines <first>..<last> (1-based, inclusive) of BRIEF.md verbatim to the end of HISTORY.md
under "## <heading>", and put the contents of <replacement-file> in their place in BRIEF.md.
Prints the first and last moved line, so the range can be checked. The project's practice:
hand-off blocks are replaced, never stacked, and the old text is kept verbatim in HISTORY.md."""
import sys
from pathlib import Path

root = Path("/root/exp/qca9377-bt-hang")
first, last, heading, repl = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3], Path(sys.argv[4])
brief = (root / "BRIEF.md").read_text().split("\n")
history = root / "HISTORY.md"
block = brief[first - 1:last]
print("first moved:", block[0][:100])
print("last moved: ", block[-1][:100])
text = history.read_text().rstrip("\n")
history.write_text(text + "\n\n## " + heading + "\n\n" + "\n".join(block) + "\n")
new = repl.read_text().rstrip("\n").split("\n")
(root / "BRIEF.md").write_text("\n".join(brief[:first - 1] + new + brief[last:]))
print(f"moved {len(block)} lines; inserted {len(new)}")
