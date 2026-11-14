#!/bin/bash
# finalize-co23.sh : copy the bot output, the run summaries and hashes into co23/
W=/root/exp/agent-work/lane2-sco-20261114
O=$W/co23
P=$W/project/tmp/bot-co23
mkdir -p "$O/bot/bot-co23/patched" "$O/bot/bot-co23/base" "$O/results"
cp "$P/summary.txt" "$O/bot/bot-co23/"
for s in patched base; do
	for f in "$P/$s"/*.log "$P/$s"/report.txt; do [[ -f "$f" ]] && cp "$f" "$O/bot/bot-co23/$s/"; done
done
for t in base-test fix-test; do
	for f in "$W/co23/asan/$t"/*.results "$W/co23/asan/$t"/commits.txt; do [[ -f "$f" ]] && cp "$f" "$O/results/$t-$(basename "$f")"; done
done
git -C "$W/bluez" log --format='%H %s' 20ffd285b58facfd1f2478d159a5f941b09d5be1..co23 > "$O/commits.txt"
( cd "$O" && find . -type f ! -path './asan/*' ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum ) > "$O/SHA256SUMS"
( cd "$O/asan" && find . -maxdepth 2 -name '*.log' -print0 | sort -z | xargs -0 sha256sum ) > "$O/SHA256SUMS-asan-logs"
echo done
