#!/bin/bash
# After the settled-files fix in the prototype: rebuild g, redo everything that involves it.
B=$WORKDIR/bin
W=$WORKDIR
D=/work/data
cd $W
# keep the rows of the first g build apart
grep -P '^g\t' results-synth.tsv > results-synth-g-before-fix.tsv
grep -vP '^g\t' results-synth.tsv > results-synth.new && mv results-synth.new results-synth.tsv
grep -P '^g\t' results-real.tsv > results-real-g-before-fix.tsv
grep -vP '^g\t' results-real.tsv > results-real.new && mv results-real.new results-real.tsv

$B/dk.sh inside-build.sh build g
$B/dk.sh inside-diff.sh g
{
echo "### main-based: f g vs e"
$B/dk.sh inside-equiv2.sh e "f g" $D/synth/sets/25 $D/synth/sets/50 $D/mixed $D/inter/off $D/inter/arch
echo "### 255.4-based: b c d vs a"
$B/dk.sh inside-equiv2.sh a "b c d" $D/synth/sets/25 $D/inter/arch
} > $W/equiv-results2.txt 2>&1
VARS="g" $B/dk.sh inside-synth.sh run
VARS="g" $B/run-real.sh
$B/run-realequiv.sh
echo ALLDONE
