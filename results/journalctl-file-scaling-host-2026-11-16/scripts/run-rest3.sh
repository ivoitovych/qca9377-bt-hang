#!/bin/bash
# the container half again, then the reproducer test again with the refined safety snapshot
B=$WORKDIR/bin
$B/run-rest2.sh
$B/run-repro-test.sh
echo REST3DONE
