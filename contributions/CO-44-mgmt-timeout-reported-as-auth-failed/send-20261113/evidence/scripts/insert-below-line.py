#!/usr/bin/python3 -I
"""insert-below-line.py <format-patch file> <text file> [KEY=VALUE-file ...]

Puts the text file's lines directly under the patch's first '---' line, followed by one empty
line, so they sit above the diffstat and git am drops them. Refuses a patch that has no '---'
line or already has text between '---' and the diffstat. Each KEY=FILE argument replaces the
placeholder @KEY@ in the text with the contents of FILE (stripped of one trailing newline).
"""
import re
import sys

patch_path, text_path = sys.argv[1], sys.argv[2]
with open(patch_path, encoding="utf-8") as f:
    lines = f.read().split("\n")
with open(text_path, encoding="utf-8") as f:
    text = f.read()
for arg in sys.argv[3:]:
    key, _, fname = arg.partition("=")
    with open(fname, encoding="utf-8") as f:
        value = f.read()
    if value.endswith("\n"):
        value = value[:-1]
    if "@%s@" % key not in text:
        sys.exit("refusing: no @%s@ in %s" % (key, text_path))
    text = text.replace("@%s@" % key, value)
text_lines = text.rstrip("\n").split("\n")

try:
    i = lines.index("---")
except ValueError:
    sys.exit("refusing: no '---' line in " + patch_path)
if not re.match(r"^ \S.* \| +\d+ ", lines[i + 1]):
    sys.exit("refusing: line after '---' is not a diffstat line: %r" % lines[i + 1])
lines[i + 1:i + 1] = text_lines + [""]
with open(patch_path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))
print("inserted %d lines below '---' in %s" % (len(text_lines), patch_path))
