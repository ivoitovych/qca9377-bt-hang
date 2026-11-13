#!/bin/bash
# run-kml-batch.sh: kmemleak runs on base-kml via run-guest.sh. Summary: logs/matrix-kml-batch.txt
set -u
w=/root/exp/agent-work/bt17-emu-20261113
out=$w/logs/matrix-kml-batch.txt
: >"$out"
run() {
	tag=$1
	label=$2
	shift 2
	"$w/harness/run-guest.sh" "$tag" "$label" "$@" >/dev/null
	rc=$?
	echo "$tag $label exit=$rc $(grep -a -h -o 'RESULT .*' "$w/logs/$tag-$label.log" | tail -n 1)" >>"$out"
}
run base-kml h-kml-healthy-1 kml --mode healthy
run base-kml h-kml-dead-1 kml --mode dead --fail-at 1
run base-kml h-kml-dead-2 kml --mode dead --fail-at 1
run base-kml h-kml-deadoff-1 kml --mode dead-off --fail-at 1
run ab-kml h-kml-healthy-1 kml --mode healthy
run ab-kml h-kml-dead-1 kml --mode dead --fail-at 1
run ab-kml h-kml-dead-2 kml --mode dead --fail-at 1
run ab-kml h-kml-deadoff-1 kml --mode dead-off --fail-at 1
echo done >>"$out"
