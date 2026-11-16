#!/bin/bash
# Inside the container: the fully interleaved sets, 1000 entries per file.
export LD_LIBRARY_PATH=/work/bins/e2
mkdir -p /work/data/inter-sets
nice -n 19 ionice -c 3 python3 -I /work/bin/make-interleaved-sets.py /work/bins/e2/systemd-journal-remote /work/data/inter-sets 1000 25 50 100 200 400
du -sh /work/data/inter-sets
