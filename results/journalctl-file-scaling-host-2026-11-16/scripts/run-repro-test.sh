#!/bin/bash
# Host side: test the reproducer in a fresh ubuntu:24.04 container, as a non-root user, against the stock
# journalctl and against variant b (mounted read-only from the build area). Output to repro-test/output.txt
W=$WORKDIR
R=$REPO
RD=$R/results/journalctl-file-scaling-verify-2026-11-15/reproducer
cd $W/repro-test
nice -n 19 docker build -q -t co46-repro:1 . > build.log 2>&1 || { echo "image build failed"; tail -5 build.log; exit 1; }
nice -n 19 docker run --rm --user tester --cpus=2 --network none \
    -v $RD:/repro:ro -v $W/bins/b:/bins/b:ro -v $W/repro-test/inside-repro-test.sh:/inside.sh:ro \
    co46-repro:1 /inside.sh /usr/bin/journalctl /bins/b/journalctl > $W/repro-test/output.txt 2>&1
echo REPRODONE $?
