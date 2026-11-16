#!/bin/bash
# After the host measurements: libsystemd for the API test, the correctness run, the unit tests. One job at a time.
B=$WORKDIR/bin
W=$WORKDIR
$B/dk.sh inside-build-lib.sh e2 p2 g2
nice -n 19 docker run --rm --cpus=3 -v $W:/work -v $REPO:/repo co46-build:1 nice -n 19 ionice -c 3 /work/pkgtest/inside-pr-correct.sh > $W/pkgtest/pr-correct.stdout 2>&1
{
$B/dk.sh inside-tests-pr.sh g2
$B/dk.sh inside-tests-pr.sh g2 -DHEAP_MIN_FILES=2
$B/dk.sh inside-tests-pr.sh p2
$B/dk.sh inside-tests-pr.sh e2
} > $W/pkgtest/pr-unit-tests.txt 2>&1
echo PRAFTERDONE
