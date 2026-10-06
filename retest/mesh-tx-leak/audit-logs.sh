#!/bin/sh
# Check every VM log under a results directory:
#   - the guest command ran to completion and reported an exit status
#   - the kernel banner matches the commit expected for that build
#   - no KASAN / lockdep / WARNING / BUG / Oops report
#   - reproducer runs ended without an ERROR line
# Usage: audit-logs.sh <logs-dir>     (exits non-zero on any problem)
set -u
LOGS=${1:?logs dir}

expected() {
	case ${1#reps-} in
	control) echo 036d4119079a ;;
	patched) echo 59f710c1a4bd ;;
	diag-control|diag-control-first-pass|probe-diag-control) echo 3792c210325e ;;
	diag-patched) echo 8ac2a343ce63 ;;
	*) echo unknown ;;
	esac
}

bad=0
printf "%-26s %-42s %-6s %-14s %s\n" build run status kernel reports
for f in "$LOGS"/*/*.log; do
	build=$(basename "$(dirname "$f")")
	run=$(basename "$f" .log)
	status=$(grep -aoE "Process [0-9]+ exited with status [0-9]+" "$f" |
		tail -1 | awk '{print $NF}')
	commit=$(grep -aoE "Linux version [^ ]+-g[0-9a-f]{12}" "$f" | head -1 |
		sed 's/.*-g//')
	reports=$(grep -acE "BUG: KASAN|WARNING:|possible circular locking|possible recursive locking|inconsistent lock state|BUG:|Oops" "$f")
	note=
	[ -z "$status" ] && { note="$note no-exit-status"; bad=1; }
	[ "$commit" != "$(expected "$build")" ] && { note="$note wrong-kernel"; bad=1; }
	[ "$reports" != 0 ] && { note="$note kernel-reports"; bad=1; }
	case $run in
	*tester*)
		# A tester must print a complete summary: one result line per
		# case, as many as its Total. It exits 1 if any case failed.
		total=$(sed 's/\x1b\[[0-9;]*m//g; s/\r$//' "$f" |
			sed -n 's/^Total: \([0-9]*\),.*Failed: \([0-9]*\),.*Not Run: \([0-9]*\).*/\1 \2 \3/p' |
			tail -1)
		cases=$(sed 's/\x1b\[[0-9;]*m//g; s/\r$//' "$f" |
			sed -n '/^Test Summary/,/^Total:/p' |
			grep -cE " (Passed|Failed|Timed out|Not Run) +[0-9.]+ seconds$")
		if [ -z "$total" ]; then
			note="$note no-tester-summary"; bad=1
		else
			set -- $total
			[ "$1" != "$cases" ] && { note="$note summary-has-$cases-of-$1"; bad=1; }
			want=0; [ "$2" != 0 ] && want=1
			[ "${status:-x}" != "$want" ] && { note="$note exit-vs-summary"; bad=1; }
		fi
		;;
	*)
		[ "${status:-x}" != 0 ] && { note="$note nonzero-exit"; bad=1; }
		grep -aq "^ERROR:" "$f" && { note="$note reproducer-error"; bad=1; }
		tr -d '\r' < "$f" | grep -aqE "^=== end scenario .* \(ok\) ===$" ||
			{ note="$note scenario-incomplete"; bad=1; }
		if grep -aq "scan=after_exit\|reproducer exited with status" "$f"; then
			tr -d '\r' < "$f" | grep -aq "^reproducer exited with status 0$" ||
				{ note="$note reproducer-failed"; bad=1; }
		fi
		# kmemleak scans: after-exit runs must show rounds 1-5 exactly;
		# in-process runs must show rounds 1..N without gaps.
		rounds=$(grep -aoE "kmemleak round=[0-9]+" "$f" | sed 's/.*=//' | tr '\n' ' ')
		if [ -n "$rounds" ]; then
			n=$(echo $rounds | wc -w)
			if grep -aq "scan=after_exit" "$f"; then
				want="1 2 3 4 5 "
			else
				want=$(seq 1 "$n" | tr '\n' ' ')
			fi
			[ "$rounds" != "$want" ] && { note="$note scans-[$rounds]"; bad=1; }
		elif grep -aq "reproducer exited with status" "$f"; then
			note="$note no-scans"; bad=1
		fi
		;;
	esac
	printf "%-26s %-42s %-6s %-14s %s%s\n" "$build" "$run" "${status:-none}" \
		"${commit:-none}" "$reports" "$note"
done
echo
[ $bad -eq 0 ] && echo "AUDIT OK" || echo "AUDIT FOUND PROBLEMS"
exit $bad
