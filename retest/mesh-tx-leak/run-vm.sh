#!/bin/sh
# Run one command in a fresh BlueZ test-runner guest.
# Usage: run-vm.sh <bzImage> <cpus> <logfile> <command...>
# Environment: BLUEZ = configured and built BlueZ tree (test-runner and
# testers are run from there).
#
# The guest console (kernel log + command output) is saved to <logfile>.
# Prints "rc=<runner> cmd=<guest command status> splat=<yes|no> <logfile>"
# and exits non-zero if the runner failed or timed out (its status), the
# guest command never reported an exit status (3), a kernel report was
# found (4), or the guest command failed (its status). A tester that has
# failing cases exits non-zero by design; see cmd= in that case.
set -u
BZ=${BLUEZ:-/home/user/work/bluez}
IMG=$1; CPUS=$2; LOG=$3; shift 3

cd "$BZ" || exit 1
timeout 3600 ./tools/test-runner -k "$IMG" -o -m -o 1024M \
	-o -smp -o "$CPUS" -- "$@" > "$LOG" 2>&1
rc=$?

cmd=$(grep -aoE "Process [0-9]+ exited with status [0-9]+" "$LOG" |
	tail -1 | awk '{print $NF}')
splat=no
grep -aqE "BUG: KASAN|WARNING:|possible circular locking|possible recursive locking|inconsistent lock state|BUG:|Oops" \
	"$LOG" && splat=yes
echo "rc=$rc cmd=${cmd:-missing} splat=$splat $LOG"

[ "$rc" -ne 0 ] && exit "$rc"
[ -z "$cmd" ] && exit 3
[ "$splat" = yes ] && exit 4
exit "$cmd"
