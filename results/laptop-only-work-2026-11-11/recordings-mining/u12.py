import glob
import re
from datetime import datetime

cancel, sw, a2 = [], [], []
for p in glob.glob("/root/exp/agent-work/laptop-evidence-mining-20261111/ext/*.tsv"):
    for line in open(p, errors="replace"):
        if "a2dp_cancel()" in line:
            cancel.append(int(line.split("\t", 1)[0]))
        elif "Setting profile of" in line and "a2dp-sink to: headset" in line:
            sw.append(int(line.split("\t", 1)[0]))
        elif "profile a2dp-sink state changed" in line:
            m = re.search(r"device ([0-9A-F:]+) profile a2dp-sink state changed: (\w+) -> (\w+)", line)
            if m:
                a2.append((int(line.split("\t", 1)[0]), m.group(2), m.group(3)))
cancel.sort(); sw.sort(); a2.sort()
f = lambda t: datetime.fromtimestamp(t / 1e6).strftime("%m-%d %H:%M:%S")
for t in cancel:
    s = [x for x in sw if abs(x - t) < 1_000_000]
    lost = [a for a in a2 if 0 <= a[0] - t <= 10_000_000 and a[2] == "disconnected" and a[1] in ("connected", "disconnecting")]
    back = [a for a in a2 if a[0] > t and a[2] == "connected"]
    gap = "%.0f s" % ((back[0][0] - t) / 1e6) if back else "not back in the logs"
    print(f(t), "switch-to-headset within 1 s:", bool(s), " a2dp-sink lost within 10 s:", bool(lost), " next a2dp-sink connected after:", gap)
