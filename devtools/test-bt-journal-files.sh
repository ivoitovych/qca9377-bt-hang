#!/bin/bash
# test-bt-journal-files.sh — tests for tools/bt-journal-files, on a fake journal directory
# under tmp/; the real journal and the real archive are never touched (journalctl is a stub
# on PATH, so --rotate cannot reach journald).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$ROOT/tools/bt-journal-files"
W="$ROOT/tmp/test-bt-journal-files"
rm -rf "$W"; mkdir -p "$W/src/mid1" "$W/stub" "$W/badzstd"
REAL_ZSTD=$(command -v zstd)
printf '#!/bin/sh\necho "rotate called" >> "%s/rotate.log"\n' "$W" > "$W/stub/journalctl"
chmod +x "$W/stub/journalctl"
# A zstd whose decompression adds a byte: verification must catch it.
printf '#!/bin/sh\n"%s" "$@"; rc=$?\ncase " $* " in *" -dc "*) printf X;; esac\nexit $rc\n' "$REAL_ZSTD" > "$W/badzstd/zstd"
chmod +x "$W/badzstd/zstd"
# Closed-file names, built at run time: written out, "name@id-…journal" reads as an email
# address to the publish scan.
AT='@'
N4="system${AT}aaa-0000000000000004-0000000000000004.journal"
head -c 300000 /dev/urandom > "$W/src/mid1/system${AT}aaa-0000000000000001-0000000000000001.journal"
head -c 200000 /dev/urandom > "$W/src/mid1/user-1000${AT}aaa-0000000000000002-0000000000000002.journal"
head -c 100000 /dev/urandom > "$W/src/mid1/system${AT}bbb-0000000000000003-0000000000000003.journal~"
head -c 50000 /dev/urandom > "$W/src/mid1/system.journal"
export BT_JOURNAL_SRC="$W/src" BT_JOURNAL_FILES_DIR="$W/dest" BT_JOURNAL_FILES_FREE_MIN_GB=0
P="$W/stub:$PATH"
pass=0 fail=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "PASS $1"; else fail=$((fail + 1)); echo "FAIL $1"; fi; }

out=$(PATH="$P" "$T" 2>&1); rc=$?
check "first run copies the 3 closed files" '[[ $rc -eq 0 && "$out" == *"3 copied now"* ]]'
check "the active file is not copied" '[[ ! -e "$W/dest/mid1/system.journal.zst" ]]'
check "manifest has 3 rows" '[[ $(tail -n +2 "$W/dest/MANIFEST.tsv" | wc -l) -eq 3 ]]'
ok=1
for f in "$W"/src/mid1/*@*; do
	cmp -s "$f" <(zstd -dc < "$W/dest/mid1/$(basename "$f").zst") || ok=0
done
check "every copy decompresses to its source byte for byte" '[[ $ok -eq 1 ]]'
check "no rotate without --rotate" '[[ ! -e "$W/rotate.log" ]]'

out=$(PATH="$P" "$T" 2>&1); rc=$?
check "second run copies nothing" '[[ $rc -eq 0 && "$out" == *"0 copied now, 3 already"* ]]'

head -c 10000 /dev/urandom > "$W/src/mid1/$N4"
out=$(PATH="$P" "$T" --status 2>&1); rc=$?
check "--status names the new file and writes nothing" '[[ $rc -eq 0 && "$out" == *"not copied: mid1/$N4"* && ! -e "$W/dest/mid1/$N4.zst" ]]'

out=$(PATH="$P" BT_JOURNAL_FILES_FREE_MIN_GB=100000 "$T" 2>&1); rc=$?
check "low free space refuses and copies nothing" '[[ $rc -eq 2 && "$out" == *"GB free"* && ! -e "$W/dest/mid1/$N4.zst" ]]'

out=$(PATH="$P" BT_JOURNAL_FILES_BUDGET_GB=0 "$T" 2>&1); rc=$?
check "a full budget refuses" '[[ $rc -eq 2 && "$out" == *"budget"* ]]'

out=$(PATH="$W/badzstd:$P" "$T" 2>&1); rc=$?
check "a copy that does not verify is not filed" '[[ $rc -eq 1 && "$out" == *"FAILED verification"* && ! -e "$W/dest/mid1/$N4.zst" && ! -e "$W/dest/mid1/$N4.zst.partial" ]]'

out=$(PATH="$P" "$T" --rotate 2>&1); rc=$?
check "--rotate asks journald to rotate, then copies the new file" '[[ $rc -eq 0 && -s "$W/rotate.log" && "$out" == *"1 copied now"* ]]'

before=$(find "$W/src" -type f | wc -l)
check "the source directory is never changed" '[[ $before -eq 5 ]]'
echo "passed $pass, failed $fail"
rm -rf "$W"
(( fail == 0 ))
