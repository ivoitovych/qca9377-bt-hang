#!/bin/bash
# inside-callgrind.sh VARIANT K LINES : callgrind of the first LINES printed lines at K synthetic files.
W=/work
v=$1; k=$2; n=${3:-3000}
export LD_LIBRARY_PATH=$W/bins/$v
out=$W/callgrind-$v-$k.out
rm -f $out
valgrind --tool=callgrind --callgrind-out-file=$out --dump-instr=no $W/bins/$v/journalctl --directory=$W/data/synth/sets/$k -o short --no-pager -n all 2>/dev/null | head -n $n > /dev/null
callgrind_annotate --inclusive=yes $out 2>&1 | head -n 45 > $W/callgrind-$v-$k.inclusive.txt
callgrind_annotate $out 2>&1 | head -n 30 > $W/callgrind-$v-$k.self.txt
echo done $v $k
