#!/bin/bash
# build-all.sh V... : build each variant in the container, one after another.
for v in "$@"; do
    echo "=== $v"
    $WORKDIR/bin/dk.sh inside-build.sh build $v || echo "FAILED $v"
done
