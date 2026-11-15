#!/bin/bash
# main-based variants on the synthetic sets (appends to the same TSV)
export VARS="e f g"
exec $WORKDIR/bin/dk.sh inside-synth.sh run
