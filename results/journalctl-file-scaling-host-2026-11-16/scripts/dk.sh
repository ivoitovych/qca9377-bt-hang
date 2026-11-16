#!/bin/bash
# dk.sh SCRIPT ARGS... : run /work/bin/SCRIPT inside the build container.
# Extra docker options via DKOPTS (e.g. the read-only real journal mount, -e VAR=value); they come last so
# that they win over the pass-through -e VAR options.
W=$WORKDIR
R=$REPO
s=$1; shift
exec nice -n 19 docker run --rm --cpus=${CPUS:-6} -v $W:/work -v $R:/repo \
    -e MAIN_REV -e VARS -e KS -e RUNS -e LINES -e SECS -e EPF -e ONLYCUR -e WHAT -e SYNTHK -e QONLY -e GK -e UNIT -e RARE \
    $DKOPTS co46-build:1 /work/bin/$s "$@"
