#!/bin/bash
# journalctl-file-scaling-repro.sh JOURNALCTL [K...]
#
# Does journalctl's cost per entry grow with the number of journal files it has open?
# Prints a table of lines/s against the number of files K, and the exponent b of
# (time to read everything) ~ K^b: b close to 2 means the read time grows with the square
# of the journal's size, close to 1 means it grows in proportion.
#
# Safe to run anywhere:
#   * needs no root; installs nothing; does not touch the system journal, /var/log/journal or journald;
#   * writes only inside one directory made with mktemp -d (removed at the end);
#   * reads only with `journalctl --directory=<that directory>/...`;
#   * the journal files are written by systemd-journal-remote from an export stream into that
#     directory (package systemd-journal-remote; its path can be given in REMOTE).
#
# JOURNALCTL is the binary to test, so two can be compared without installing either:
#   archive's:        ./journalctl-file-scaling-repro.sh /usr/bin/journalctl
#   a patched build:  ninja -C build journalctl      # in a systemd source tree, nothing is installed
#                     ./journalctl-file-scaling-repro.sh /path/to/tree/build/journalctl
#   A binary from a build tree finds its libsystemd-shared-*.so in its own directory or in
#   <its directory>/src/shared; this script puts those on LD_LIBRARY_PATH for that one process only.
#
# K defaults to "25 50 100 200 400". Environment: KEEP (set it to keep the files for further checks, such as
# `journalctl --verify --directory=<dir>/all`), ENTRIES (entries per file, default 1000),
# LINES (stop after this many lines, default 100000), SECS (per run, default 40), RUNS (default 3,
# the median is used), REMOTE (path of systemd-journal-remote), REMOTE_LIBDIR (where its
# libsystemd-shared is, if it is not installed).
set -u

jc=${1:?usage: $0 JOURNALCTL [K...]}
shift
KS=${*:-25 50 100 200 400}
ENTRIES=${ENTRIES:-1000}; LINES=${LINES:-100000}; SECS=${SECS:-40}; RUNS=${RUNS:-3}

jc=$(readlink -f "$jc") || exit 1
[ -x "$jc" ] || { echo "not an executable: $jc" >&2; exit 1; }

remote=${REMOTE:-}
if [ -z "$remote" ]; then
    for c in /usr/lib/systemd/systemd-journal-remote /lib/systemd/systemd-journal-remote "$(command -v systemd-journal-remote)"; do
        [ -n "$c" ] && [ -x "$c" ] && { remote=$c; break; }
    done
fi
[ -n "$remote" ] || { echo "systemd-journal-remote not found. Install the package systemd-journal-remote, or set REMOTE=<path> (and REMOTE_LIBDIR=<dir with libsystemd-shared>)." >&2; exit 1; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/journalctl-scaling.XXXXXX") || exit 1
case $tmp in /*/journalctl-scaling.*) ;; *) echo "unexpected temp dir $tmp" >&2; exit 1 ;; esac
if [ -n "${KEEP:-}" ]; then
    echo "KEEP is set: the files stay in $tmp (delete it yourself when done, for example with rm -rf)"
else
    trap 'rm -rf -- "$tmp"' EXIT
fi
mkdir "$tmp/all"

maxk=0; for k in $KS; do [ "$k" -gt "$maxk" ] && maxk=$k; done

jcdir=$(dirname "$jc")
export LD_LIBRARY_PATH="$jcdir:$jcdir/src/shared${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
remote_ld=${REMOTE_LIBDIR:+$REMOTE_LIBDIR:}${LD_LIBRARY_PATH:-}

echo "journalctl under test: $jc ($(LD_LIBRARY_PATH=$LD_LIBRARY_PATH "$jc" --version | head -n 1))"
echo "journal files are written under: $tmp (removed at the end); the system journal is not read or written"
echo "writing $maxk files of $ENTRIES entries each, archived, 5 files per boot ..."

# One export-format stream per file: consecutive time slices, a new boot every 5 files, one machine ID.
realtime=1700000000000000; seq=0
for ((i = 0; i < maxk; i++)); do
    b=$((i / 5))
    f=$(printf '%s/all/system@%05d.journal' "$tmp" "$i")
    awk -v rt="$realtime" -v n="$ENTRIES" -v i="$i" -v b="$b" -v seq="$seq" -v newboot=$((i % 5 == 0)) 'BEGIN {
        if (newboot) rt += 60000000
        mono = 5000000 + (i % 5) * n * 2000
        boot = sprintf("%08x", b) "b007b007b007b007b007b007"
        for (e = 0; e < n; e++) {
            rt += 2000; mono += 2000; seq++
            printf "__REALTIME_TIMESTAMP=%d\n__MONOTONIC_TIMESTAMP=%d\n_BOOT_ID=%s\n_MACHINE_ID=0123456789abcdef0123456789abcdef\n", rt, mono, boot
            printf "_HOSTNAME=repro\n_TRANSPORT=kernel\nSYSLOG_IDENTIFIER=kernel\nPRIORITY=6\nMESSAGE=synthetic line %d in file %d boot %d\n\n", seq, i, b
        }
    }' > "$tmp/stream" || exit 1
    # advance the clock exactly as the awk program did
    [ $((i % 5)) -eq 0 ] && realtime=$((realtime + 60000000))
    realtime=$((realtime + ENTRIES * 2000)); seq=$((seq + ENTRIES))
    LD_LIBRARY_PATH=$remote_ld "$remote" --output="$f" - < "$tmp/stream" > /dev/null 2> "$tmp/err" \
        || { echo "systemd-journal-remote failed on file $i:" >&2; cat "$tmp/err" >&2; exit 1; }
    printf '\002' | dd of="$f" bs=1 seek=16 conv=notrunc 2> /dev/null    # header state: ARCHIVED, as rotated files are
done
rm -f "$tmp/stream"

printf '\n%6s %10s %10s %12s %14s\n' K lines seconds lines/s us/entry
xs=(); ys=()
for k in $KS; do
    mkdir "$tmp/set$k"
    for f in $(ls "$tmp"/all/*.journal | sort | head -n "$k"); do ln "$f" "$tmp/set$k/"; done
    rates=()
    for ((r = 0; r < RUNS; r++)); do
        t0=$(date +%s.%N)
        n=$(timeout "$SECS" "$jc" --directory="$tmp/set$k" -o short --no-pager 2> /dev/null | head -n "$LINES" | wc -l)
        t1=$(date +%s.%N)
        rates+=("$(awk -v n="$n" -v a="$t0" -v b="$t1" 'BEGIN { printf "%.3f %d %.3f", n / (b - a), n, b - a }')")
    done
    med=$(printf '%s\n' "${rates[@]}" | sort -g | awk '{ r[NR] = $0 } END { print r[int((NR + 1) / 2)] }')
    set -- $med
    printf '%6d %10d %10.2f %12.0f %14.1f\n' "$k" "$2" "$3" "$1" "$(awk -v r="$1" 'BEGIN { printf "%.1f", 1e6 / r }')"
    [ "$k" -ge 50 ] && { xs+=("$k"); ys+=("$1"); }
done

# exponent: slope of log(cost per entry) against log(K) over K >= 50, plus 1 (N is proportional to K)
if [ "${#xs[@]}" -ge 2 ]; then
    paste <(printf '%s\n' "${xs[@]}") <(printf '%s\n' "${ys[@]}") | awk '
        { x = log($1); y = log(1 / $2); sx += x; sy += y; sxx += x * x; sxy += x * y; n++ }
        END { s = (n * sxy - sx * sy) / (n * sxx - sx * sx)
              printf "\nexponent b of (time to read everything) ~ K^b, K >= 50: %.2f   (2 = quadratic, 1 = linear)\n", 1 + s }'
fi
