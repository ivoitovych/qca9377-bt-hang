#!/bin/bash
# Inside the container: the equivalence sets that are not part of the scaling sets.
#  inter/off, inter/arch : 60 files over 12 boots whose time windows overlap, copied stretches (OFFLINE / ARCHIVED)
#  mixed                 : 40 consecutive files of the scaling set, files 3, 17, 39 left ONLINE (state 1)
set -eu
W=/work
export LD_LIBRARY_PATH=$W/bins/a
if [ ! -d $W/data/inter ]; then
    mkdir -p $W/data/inter
    sed "s#^REMOTE = .*#REMOTE = '$W/bins/a/systemd-journal-remote'#" /repo/results/journalctl-file-scaling-cause-2026-11-14/make-journals-interleaved.py > $W/data/mji.py
    python3 -I $W/data/mji.py $W/data/inter/off 60 3000 12
    mkdir -p $W/data/inter/arch
    cp $W/data/inter/off/*.journal $W/data/inter/arch/
    python3 -I $W/bin/fixstate.py $W/data/inter/arch
fi
if [ ! -d $W/data/mixed ]; then
    mkdir -p $W/data/mixed
    for f in $(ls $W/data/synth/all/*.journal | sort | head -n 40); do cp $f $W/data/mixed/; done
    for i in 00003 00017 00039; do printf '\001' | dd of=$W/data/mixed/system@$i.journal bs=1 seek=16 conv=notrunc 2>/dev/null; done
fi
ls $W/data
