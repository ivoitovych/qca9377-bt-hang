#!/bin/bash
# SHA256SUMS of the package: patches*, logs, fetched, scripts, and the per-run files of runs/* (not the build trees).
cd /root/exp/agent-work/lane4-bluez-20261114/co37 || exit 2
: > SHA256SUMS
{
    find patches patches-placeholder-author patches-series-B-standalone logs fetched scripts -type f
    find runs -mindepth 2 -maxdepth 2 -type f
    ls *.md
} | sort | while read -r f; do
    nice -n 19 ionice -c 3 sha256sum "$f" >> SHA256SUMS
done
wc -l SHA256SUMS
