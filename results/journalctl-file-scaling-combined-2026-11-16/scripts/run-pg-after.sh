#!/bin/bash
# Part 1, after the host rates: libsystemd for the API test, correctness, unit tests (one job at a time).
B=$WORKDIR/bin
W=$WORKDIR
$B/dk.sh inside-build-lib.sh pg2a pg2b
nice -n 19 docker run --rm --cpus=3 -v $W:/work -v $REPO:/repo co46-build:1 nice -n 19 ionice -c 3 /work/pkgtest/inside-pg-correct.sh > $W/pkgtest/pg-correct.stdout 2>&1
{
$B/dk.sh inside-tests-pr.sh pg2a
$B/dk.sh inside-tests-pr.sh pg2a -DHEAP_MIN_FILES=2
$B/dk.sh inside-tests-pr.sh pg2b
$B/dk.sh inside-tests-pr.sh pg2b -DHEAP_MIN_FILES=2
} > $W/pkgtest/pg-unit-tests.txt 2>&1
echo PGAFTERDONE
