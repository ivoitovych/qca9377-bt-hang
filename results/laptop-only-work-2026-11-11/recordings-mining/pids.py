import glob
from collections import defaultdict
for p in sorted(glob.glob("/root/exp/agent-work/laptop-evidence-mining-20261111/ext/*.tsv")):
    d = defaultdict(set)
    for line in open(p, errors="replace"):
        f = line.split("\t", 6)
        if len(f) == 7 and f[1] in ("bluetoothd", "wireplumber", "pipewire", "pipewire-pulse", "gnome-control-center", "gnome-shell"):
            d[f[1]].add(f[2])
    print(p.rsplit("/", 1)[1][:-4], {k: len(v) for k, v in sorted(d.items())})
