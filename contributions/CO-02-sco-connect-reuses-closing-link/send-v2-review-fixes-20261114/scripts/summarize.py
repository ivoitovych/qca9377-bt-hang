"""summarize.py : per kernel and label, the totals over the run logs and the cases that did not pass.
Usage: python3 -I summarize.py <label>...   (reads logs/run-<label>-<kernel>-<n>.log)"""
import re, sys, glob, os, collections

W = "/root/exp/agent-work/lane7-sco-20261114"
ansi = re.compile(r"\x1b\[[0-9;]*m")
for label in sys.argv[1:]:
    runs = collections.defaultdict(list)
    for f in sorted(glob.glob("%s/logs/run-%s-*-*.log" % (W, label))):
        m = re.match(r"run-%s-(.+)-(\d+)\.log" % re.escape(label), os.path.basename(f))
        kern = m.group(1)
        text = ansi.sub("", open(f, errors="replace").read())
        tot = re.findall(r"Total: (\d+), Passed: (\d+) .*?Failed: (\d+), Not Run: (\d+)", text)
        res = re.findall(r"^(.+?)\s+(Passed|Failed|Timed out|Not Run)\s+[\d.]+ seconds", text, re.M)
        bad = sorted(set(n.strip() + " [" + s + "]" for n, s in res if s != "Passed"))
        runs[kern].append((tot[-1] if tot else None, bad))
    for kern, lst in sorted(runs.items()):
        print("%s %s: %d runs" % (label, kern, len(lst)))
        for tot, bad in lst:
            print("   total/pass/fail/notrun %s" % (tot,))
        allbad = collections.Counter()
        for tot, bad in lst:
            for b in bad:
                allbad[b] += 1
        for b, c in sorted(allbad.items()):
            print("   %d of %d: %s" % (c, len(lst), b))
