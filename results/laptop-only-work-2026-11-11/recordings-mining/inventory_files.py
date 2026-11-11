#!/usr/bin/env python3
"""list per-day counts and sizes of capture files in each source directory"""
import os
import re
import sys
from collections import defaultdict

SRC = {
    "capture": "/var/log/bt-health/capture",
    "trace": "/var/log/bt-health/trace",
    "arch-hci": "/root/exp/qca9377-bt-hang/archive/hci-capture",
    "arch-trace": "/root/exp/qca9377-bt-hang/archive/bt-trace",
}
for k, d in SRC.items():
    per = defaultdict(lambda: [0, 0])
    for f in os.listdir(d):
        m = re.match(r"(?:hci|bt)-(\d{8})-(\d{6})", f)
        if not m:
            continue
        s = os.path.getsize(os.path.join(d, f))
        per[m.group(1)][0] += 1
        per[m.group(1)][1] += s
    print("==", k, len(per), "days")
    for day in sorted(per):
        print(day, per[day][0], "files", per[day][1] // 1000000, "MB")
