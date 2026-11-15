#!/bin/bash
# dk.sh SCRIPT ARGS... : run /work/bin/SCRIPT inside the build container.
# Extra docker options via DKOPTS (e.g. the read-only real journal mount).
W=$WORKDIR
R=$REPO
s=$1; shift
exec nice -n 19 docker run --rm --cpus=${CPUS:-6} -v $W:/work -v $R:/repo $DKOPTS \
    -e MAIN_REV -e VARS -e KS -e RUNS -e LINES -e SECS -e OUT -e EPF co46-build:1 /work/bin/$s "$@"
