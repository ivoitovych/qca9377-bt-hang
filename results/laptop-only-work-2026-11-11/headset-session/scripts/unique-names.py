#!/usr/bin/env python3
"""Count the distinct 'quirk property name=' values in a saved `journalctl -o cat -g` output.
Usage: unique-names.py <file>"""
import collections
import re
import sys

c = collections.Counter()
v = collections.Counter()
for line in open(sys.argv[1], errors="replace"):
    m = re.match(r"quirk property name=(.*)", line)
    if m:
        c[m.group(1)] += 1
    m = re.match(r"quirk property (vendor-id|product-id|version-id)=(.*)", line)
    if m:
        v[(m.group(1), m.group(2))] += 1
for n, k in c.most_common():
    print("%6d  name=%s" % (k, n))
print("distinct id values seen (adapter included):")
for (k, val), n in v.most_common():
    print("%6d  %s=%s" % (n, k, val))
