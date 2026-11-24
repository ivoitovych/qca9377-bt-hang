#!/bin/bash
# run-stable.sh : waits for "suites done (tips2)" in the other queue's progress.log, then for each stable line:
# build both kernels (+ W=1), run its spec, and pack the line's raw logs into archives/stable-<line>.tar.zst
# (zstd -19; the logs themselves are kept). One heavy job at a time. Progress in progress.log.
w=${CO43_WORK}
"$w/scripts/wait-for-line.sh" ${WORK}/progress.log "suites done (tips2, final)" 86400 || { echo "$(date '+%F %T') stable: no 'suites done (tips2, final)' in 24 h, stopping" >>"$w/progress.log"; exit 1; }
# an orphaned build-line.sh from the mistaken start must be finished before anything else runs
while pgrep -f "scripts/build-line.sh" >/dev/null; do sleep 15; done
echo "$(date '+%F %T') stable: 'suites done (tips2, final)' seen, starting" >>"$w/progress.log"
mkdir -p "$w/summaries" "$w/archives"
for l in ${LINES:-7.3 6.18 6.12 6.6 6.1 5.15 5.10}; do
	echo "$(date '+%F %T') stable $l build start" >>"$w/progress.log"
	"$w/scripts/build-line.sh" "$l" >"$w/logs/build-stable-$l.log" 2>&1
	echo "$(date '+%F %T') stable $l build end" >>"$w/progress.log"
	"$w/scripts/extra-line.sh" "$l" >"$w/logs/extra-line-$l.log" 2>&1
	echo "$(date '+%F %T') stable $l extra (tree check, CONFIG_PM off W=1) end" >>"$w/progress.log"
	if [ -e "$w/img/bzImage-s$l-base" ] && [ -e "$w/img/bzImage-s$l-p1" ]; then
		"$w/scripts/run-batch.sh" "$w/specs/stable-$l.txt" "$w/summaries/stable-$l.txt"
		echo "$(date '+%F %T') stable $l batch end rc=$?" >>"$w/progress.log"
	else
		echo "$(date '+%F %T') stable $l: image missing, batch skipped" >>"$w/progress.log"
	fi
	( cd "$w" && tar -cf - logs/runs/s$l-base-*.log logs/runs/s$l-p1-*.log logs/w1/w1-$l-*.log logs/build-stable-$l.log 2>/dev/null | nice -n 19 zstd -19 -q -f -o "archives/stable-$l.tar.zst" )
	echo "$(date '+%F %T') stable $l archived" >>"$w/progress.log"
done
( cd "$w/archives" && sha256sum stable-*.tar.zst >SHA256SUMS )
echo "$(date '+%F %T') stable run-stable end" >>"$w/progress.log"
