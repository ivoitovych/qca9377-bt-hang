#!/bin/bash
# Inside co46-build:1: how big is a journal file of N entries made by the noble-default generator?
export LD_LIBRARY_PATH=/work/bins/e2
rm -rf /work/data/calib; mkdir -p /work/data/calib
for n in 20000 40000; do
    nice -n 19 ionice -c 3 python3 -I /work/bin/make-noble-default.py /work/bins/e2/systemd-journal-remote /work/data/calib --calibrate $n
done
rm -rf /work/data/calib
