#!/usr/bin/env python3
"""summarize-stress.py <log>...: one markdown table row per stress log, from its RESULT stress line,
its run-guest exit line and its counts of PARKED, KERNEL-REPORT, KERNEL-TIMEOUT, TEARDOWN-TIMEOUT and
re-queued-event lines. A log without a RESULT line is listed as such (interrupted or failed)."""
import os
import re
import sys

print("| log | runner rc | BT17-EXIT | cycles | normal ok | disruptions recovered | packets | device suspends/resumes "
      "| parked | tx timeouts | teardown timeouts | kernel reports | kmemleak (BT-25 sig./other) | events re-queued |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
for path in sys.argv[1:]:
    text = open(path, encoding="utf-8", errors="replace").read()
    name = os.path.basename(path)[:-4]
    ex = re.findall(r"^exit=(\d+) end", text, re.M)
    verdict = re.findall(r"BT17-EXIT ([01])", text)
    m = re.search(r"RESULT stress (.*)", text)
    if not m:
        print("| %s | %s | %s | no RESULT line | | | | | | | | | | |" %
              (name, ex[-1] if ex else "none", verdict[-1] if verdict else "none"))
        continue
    kv = dict(x.split("=", 1) for x in m.group(1).split())
    print("| %s | %s | %s | %s | %s/%s | %s/%s | %s | %s/%s | %s | %s | %s | %s | %s/%s | %d |" % (
        name, ex[-1] if ex else "none", verdict[-1] if verdict else "none", kv["cycles"],
        kv["normal_ok"], kv["normal"], kv["recovered"], kv["disruptions"], kv["packets_sent"],
        kv.get("device_suspends", "?"), kv.get("device_resumes", "?"), kv["parked"], kv["tx_timeouts"],
        kv.get("teardown_timeouts", "?"), kv["kernel_reports"], kv.get("kmemleak_bt25_signature", "?"),
        kv.get("kmemleak_other", "?"), text.count("event bytes put back")))
