#!/bin/bash
# Host side: build the equivalence sets, then compare. Output to the work dir.
B=$WORKDIR/bin
W=$WORKDIR
$B/dk.sh inside-mkinter.sh
D=/work/data
{
echo "### main-based: f g vs e"
$B/dk.sh inside-equiv2.sh e "f g" $D/synth/sets/25 $D/synth/sets/50 $D/mixed $D/inter/off $D/inter/arch
echo "### 255.4-based: b c d vs a"
$B/dk.sh inside-equiv2.sh a "b c d" $D/synth/sets/25 $D/mixed $D/inter/off $D/inter/arch
} > $W/equiv-results.txt 2>&1
