#!/bin/sh
# Build and run the CO-03 L1 harness (test-co03-transport.c) against a
# configured BlueZ tree, with ASan and UBSan, in co03-noble-build:1.
#
# Usage: run-l1.sh [--verify <expected file>] [--docker <program>]
#                  [--harness <dir>] <configured tree> <log file>
#
# Observation mode (default, as the earlier runner): prints the container
# exit and the RESULT/SUMMARY/sanitizer lines; exit 0 if any RESULT line
# was printed, 1 otherwise. Buggy baselines are expected to fail tests
# here; nothing is judged.
#
# Verify mode (--verify): verify-l1.py judges the log against the expected
# results (one "<ID> PASS|FAIL" line per test) and this script exits with
# its status: non-zero on a container or build failure, a harness crash or
# non-zero harness exit, any sanitizer report, a missing or malformed
# RESULT or SUMMARY record, a duplicate or unknown test ID, an outcome
# other than the expected one, a missing expected test ID, or a count
# mismatch.
#
# --docker: the program run in place of docker (tests use a stub).
# --harness: directory holding test-co03-transport.c (default: the
# earlier CO-03 harness, /root/exp/agent-work/co03/tests/l1).
#
# Inside the container nothing stops at the first error: the compile
# status ("BUILD OK" / "BUILD FAILED <rc>") and the harness status
# ("harness exit <rc>") are always printed, and the container exits with
# 90 on a build failure, else with the harness's own status.
set -u
R=/root/exp/agent-work/co03/review-20261101
expected=""
docker=docker
harness=/root/exp/agent-work/co03/tests/l1
while [ $# -gt 2 ]; do
    case "$1" in
        --verify) expected=$2; shift 2 ;;
        --docker) docker=$2; shift 2 ;;
        --harness) harness=$2; shift 2 ;;
        *) echo "usage: run-l1.sh [--verify <expected>] [--docker <prog>] [--harness <dir>] <tree> <log>" >&2; exit 2 ;;
    esac
done
if [ $# -ne 2 ]; then
    echo "usage: run-l1.sh [--verify <expected>] [--docker <prog>] [--harness <dir>] <tree> <log>" >&2
    exit 2
fi
tree=$1
log=$2
if [ -n "$expected" ] && [ ! -f "$expected" ]; then
    echo "expected-results file not found: $expected" >&2
    exit 2
fi
"$docker" run --rm -v "$tree:/b:ro" -v "$harness:/t:ro" -w /tmp co03-noble-build:1 sh -c '
gcc -g -O1 -fno-omit-frame-pointer -fsanitize=address -fsanitize=undefined \
    -fno-sanitize-recover=undefined -DHAVE_CONFIG_H \
    -I/b -I/b/lib $(pkg-config --cflags glib-2.0 dbus-1) \
    -Wall -Wno-unused-function -Wno-unused-variable \
    -o /tmp/test-co03-transport /t/test-co03-transport.c \
    $(pkg-config --libs glib-2.0 dbus-1)
rc=$?
if [ $rc -ne 0 ]; then
    echo "BUILD FAILED $rc"
    exit 90
fi
echo "BUILD OK"
ASAN_OPTIONS=detect_leaks=1:abort_on_error=0:halt_on_error=1 \
UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 \
    /tmp/test-co03-transport
rc=$?
echo "harness exit $rc"
exit $rc
' > "$log" 2>&1
crc=$?
echo "container exit $crc" >> "$log"
echo "container exit $crc"
if [ -n "$expected" ]; then
    python3 -I "$R/scripts/verify-l1.py" "$expected" "$log" "$crc"
    exit $?
fi
grep -E "^(RESULT|SUMMARY|BUILD|harness exit)|ERROR: AddressSanitizer|runtime error|LeakSanitizer" "$log"
# observation mode: exit 0 whenever the harness printed results at all
grep -q '^RESULT ' "$log"
