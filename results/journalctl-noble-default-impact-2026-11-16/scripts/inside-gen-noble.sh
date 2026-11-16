#!/bin/bash
# Inside co46-build:1: the noble-default synthetic journal and its subsets (hard links, same file system).
set -u
export LD_LIBRARY_PATH=/work/bins/e2
R=/work/data/noble-default
mkdir -p $R
# the newest boot gets this machine's current boot ID (the container shares the host kernel's), so that `-b`
# and `-b -1` mean what they mean on a real system; the ID is not printed
export LASTBOOT=$(tr -d - < /proc/sys/kernel/random/boot_id)
nice -n 19 ionice -c 3 python3 -I /work/bin/make-noble-default.py /work/bins/e2/systemd-journal-remote $R/all \
    --entries-system 48000 --entries-user 30000
du -sh $R/all/system $R/all/user
ls $R/all/system | wc -l
ls $R/all/user | wc -l
python3 -I - <<'EOF'
import os
R = "/work/data/noble-default"
sysf = sorted(os.listdir(f"{R}/all/system"))
usrf = sorted(os.listdir(f"{R}/all/user"))
def key(kind, name):
    b = int(name.split("@")[1][:3]); k = int(name.split("@")[1][3:6])
    per = 10 if kind == "s" else 5
    return (b, (k + 1) / per)
allf = [(key("s", n), "system", n) for n in sysf] + [(key("u", n), "user", n) for n in usrf]
allf.sort(reverse=True)           # newest first
def mk(name, items):
    d = f"{R}/{name}"
    os.makedirs(d, exist_ok=True)
    for sub, n in items:
        p = f"{d}/{n}"
        if not os.path.exists(p):
            os.link(f"{R}/all/{sub}/{n}", p)
    print(name, len(items), "files")
for K in (25, 50, 150):
    mk(f"mixed-{K}", [(s, n) for _, s, n in allf[:K]])
sysnew = sorted([(key("s", n), n) for n in sysf], reverse=True)
for K in (25, 50, 100):
    mk(f"sys-{K}", [("system", n) for _, n in sysnew[:K]])
for K in (25, 50, 150):
    d = f"{R}/mixed-{K}"
    nu = sum(1 for n in os.listdir(d) if n.startswith("user-"))
    print(f"mixed-{K}: {nu} user files")
EOF
df -h /work | tail -1
