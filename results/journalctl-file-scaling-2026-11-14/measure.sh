#!/bin/bash
# measure.sh: journalctl output rate, 60 s per variant, lowest CPU and disk priority.
# Read-only; output text is counted, not kept. Prints bytes and lines per variant.
set -u
run() {
	local label=$1
	shift
	local t0 t1 out
	t0=$(date +%s.%N)
	out=$(nice -n 19 ionice -c 3 timeout 60 journalctl --no-pager "$@" 2> /dev/null | wc -c -l)
	t1=$(date +%s.%N)
	echo "$label	$(echo "$t1 - $t0" | bc)	s	lines bytes: $out	args: $*"
}
echo "journal files: $(find /var/log/journal -name '*.journal*' | wc -l); size: $(du -sh /var/log/journal | cut -f1)"
run "kernel, current boot" -k -b 0
run "kernel, all boots" -k -b all
run "everything, current boot" -b 0
run "everything, all files, no filter"
run "kernel, all boots, -o cat" -k -b all -o cat
