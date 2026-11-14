"""strip-notes-ws.py <mail>... : turn the 4-space blank lines git format-patch --notes writes into empty lines
(the BlueZ bot's gitlint rejects trailing whitespace in the message); diff lines are untouched."""
import sys

for path in sys.argv[1:]:
    lines = open(path).read().split("\n")
    in_diff = False
    out = []
    for line in lines:
        if line.startswith("diff --git"):
            in_diff = True
        if not in_diff and line == "    ":
            line = ""
        out.append(line)
    open(path, "w").write("\n".join(out))
