#!/bin/bash
# Whole-journal reads (no line cap below the journal's size) on the sequential synthetic sets, so that the cost of the
# file boundaries is included: e2 (main at the PR base), p2 (+ PR #44579), g2 (+ our queue prototype).
export W=$WORKDIR
export ENVNAME=host REALGLOB='/var/log/journal/*/'
export VARS="e2 p2 g2"
M=$W/bin/measure-runs.sh
OUT=$W/pr-synth-seq-full.tsv WHAT=synth LABEL=_full LINES=2000000 SECS=150 KS="25 50 100 200 400 800" nice -n 19 ionice -c 3 $M
echo HOSTPR2DONE
