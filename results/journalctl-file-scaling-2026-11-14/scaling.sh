#!/bin/bash
# scaling.sh: journalctl output rate as a function of the number of journal files opened.
# The newest K files (by mtime) are passed with --file; 20 s each; nice 10, low disk priority.
# Read-only: output is counted, never kept. Also: exit status and stderr of "-k -b all".
set -u
dir=$(ls -d /var/log/journal/*/ | head -1)
mapfile -t files < <(ls -t "$dir"*.journal*)
echo "files available: ${#files[@]}"
for k in 1 2 5 10 25 50 100 200 400 ${#files[@]}; do
	sel=("${files[@]:0:$k}")
	args=()
	for f in "${sel[@]}"; do args+=("--file=$f"); done
	t0=$(date +%s.%N)
	out=$(nice -n 10 ionice -c 2 -n 7 timeout 20 journalctl --no-pager -o short "${args[@]}" 2> /dev/null | wc -l)
	t1=$(date +%s.%N)
	echo "K=$k	lines=$out	seconds=$(echo "$t1 - $t0" | bc)	lines/s=$(echo "$out / ($t1 - $t0)" | bc)"
done
echo "--- -k -b all: exit status and stderr (first 30 s)"
nice -n 10 ionice -c 2 -n 7 timeout 30 journalctl --no-pager -k -b all > /dev/null 2> "$(dirname "$0")/kball.stderr"
echo "exit $?"
head -5 "$(dirname "$0")/kball.stderr"
