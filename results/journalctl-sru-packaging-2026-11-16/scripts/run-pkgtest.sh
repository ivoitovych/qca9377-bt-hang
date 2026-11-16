#!/bin/bash
# Host side: the package test in a fresh ubuntu:24.04 container (root for the installation, then user "tester").
W=$WORKDIR
R=$REPO
mkdir -p $W/pkgtest/result
nice -n 19 docker run --rm --cpus=2 \
    -v $W:/work -v $R/results/journalctl-file-scaling-host-2026-11-16/reproducer:/repro:ro \
    ubuntu:24.04 nice -n 19 ionice -c 3 /work/pkgtest/inside-pkgtest.sh
echo PKGTESTDONE $?
