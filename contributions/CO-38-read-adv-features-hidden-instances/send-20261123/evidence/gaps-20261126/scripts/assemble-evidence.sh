#!/bin/bash
# assemble-evidence.sh : the 2026-11-26 suite-gap evidence into the CO-38 dossier, as tips-20261123/ was:
# scripts, case lists, comparisons, kernel-report scan, image versions, bot summaries, SHA-256 of every raw log;
# the raw logs themselves into one zstd archive in the private backup/local-work. Refuses an existing destination.
set -u
R=/root/exp/qca9377-bt-hang
D=$R/tmp/kernel-queue-20261126
W3=<work area>/tips3
E=$R/contributions/CO-38-read-adv-features-hidden-instances/send-20261123/evidence/gaps-20261126
B=/root/exp/private-backup-local-work/2026-11-26-test-runs
[[ -e $E || -e $B ]] && { echo "exists, refusing: $E or $B" >&2; exit 1; }
mkdir -p "$E/scripts" "$E/lists" "$E/versions" "$E/bot" "$B"
for f in all-gaps.sh build-next2.sh run-gaps.sh cases-after.py compare-gaps.sh bot-co38.sh bot-base-rerun.sh \
	health.sh watch-gaps.sh assemble-evidence.sh; do
	cp "$D/$f" "$E/scripts/$f"
done
cp "$W3"/lists/*.txt "$E/lists/"
cp "$W3"/img/*.versions "$E/versions/"
cp "$W3/compare-gaps.txt" "$E/compare-gaps.txt"
cp "$W3/report-scan.txt" "$E/report-scan.txt"
cp "$W3/progress.log" "$E/progress.log"
for s in bot-co38-k bot-co38-bluez bot-co38-k-base; do
	[[ -f $D/$s/summary.txt ]] && cp "$D/$s/summary.txt" "$E/bot/$s-summary.txt"
	[[ -f $D/$s.log ]] && cp "$D/$s.log" "$E/bot/$s.log"
done
# Raw logs: their SHA-256 in the dossier, the logs in the private archive.
(cd "$W3/runs" && sha256sum -- *.log) > "$E/SHA256SUMS-raw-logs"
tar -C "$W3" -cf - runs | zstd -19 -q -o "$B/gaps-20261126-runs.tar.zst"
for s in bot-co38-k bot-co38-bluez bot-co38-k-base; do
	[[ -d $D/$s ]] && tar -C "$D" -cf - --exclude=work "$s" | zstd -19 -q -o "$B/$s.tar.zst"
done
(cd "$B" && sha256sum -- *.tar.zst) > "$B/SHA256SUMS"
sha256sum "$B"/*.tar.zst | sed -e "s|$B/||" > "$E/SHA256SUM-private-archive"
(cd "$E" && find . -type f ! -name SHA256SUMS -printf '%P\n' | sort | xargs -d '\n' sha256sum) > "$E/SHA256SUMS"
echo "evidence: $(find "$E" -type f | wc -l) files, $(du -sh "$E" | cut -f1); archive: $(du -sh "$B" | cut -f1)"
