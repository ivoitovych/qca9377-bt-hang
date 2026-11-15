#!/bin/bash
# The four cursor queries again, with the cursor of the 3000th entry (the first try used the first entry's).
B=$WORKDIR/bin
W=$WORKDIR
D=/work/data
export ONLYCUR=1
{
echo "### cursor queries, main-based: f g vs e"
$B/dk.sh inside-equiv2.sh e "f g" $D/synth/sets/25 $D/synth/sets/50 $D/mixed $D/inter/off $D/inter/arch
echo "### cursor queries, 255.4-based: b c d vs a"
$B/dk.sh inside-equiv2.sh a "b c d" $D/synth/sets/25 $D/inter/arch
} > $W/equiv-results3.txt 2>&1
