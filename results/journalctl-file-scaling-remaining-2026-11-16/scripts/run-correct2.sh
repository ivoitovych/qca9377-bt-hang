#!/bin/bash
W=$WORKDIR
nice -n 19 docker run --rm --cpus=3 -v $W:/work -v $REPO:/repo co46-build:1 nice -n 19 ionice -c 3 /work/pkgtest/inside-pr-correct2.sh > $W/pkgtest/pr-correct2.stdout 2>&1
echo CORRECT2DONE $?
