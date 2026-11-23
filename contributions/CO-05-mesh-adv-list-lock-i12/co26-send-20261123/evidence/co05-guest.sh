#!/bin/bash
# co05-guest.sh <fail-count> <command> [args...] - runs INSIDE the test-runner
# guest (qemu), never on the host. W4 / CO-26: sets the scratch module
# parameter bluetooth.scratch_fail_mesh_add (the next N mesh adds fail with
# -ENOMEM), installs kprobe events on the mesh start path, runs the command,
# prints the trace buffer. "@send" as the command stands for the BlueZ master
# mesh-tester run with -s Send (test-runner splits TESTARGS on spaces).
set -u
N="$1"; shift
if [ "${1:-}" = "@send" ]; then
	set -- /root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/standalone/bin-unpatched/mesh-tester -d -s Send
fi
echo "command: $*"
echo "guest CPUs online: $(cat /sys/devices/system/cpu/online)"
T=/sys/kernel/debug/tracing
if [ ! -d "$T" ]; then
	mkdir -p /sys/kernel/tracing
	mount -t tracefs nodev /sys/kernel/tracing
	T=/sys/kernel/tracing
fi
echo "tracefs at $T"
add() {
	if echo "$1" >> "$T/kprobe_events"; then
		echo "kprobe added: $1"
	else
		echo "kprobe NOT added: $1"
	fi
}
echo 0 > /proc/sys/debug/kprobes-optimization
: > "$T/kprobe_events"
add 'p:co05/send_sync mesh_send_sync'
add 'r:co05/send_sync_ret mesh_send_sync ret=$retval:s32'
add 'r:co05/add_ret hci_add_adv_instance ret=$retval:x64'
add 'p:co05/sched hci_schedule_adv_instance_sync instance=$arg2:u8 force=$arg3:u8'
add 'r:co05/sched_ret hci_schedule_adv_instance_sync ret=$retval:s32'
add 'p:co05/start_cmpl mesh_send_start_complete err=$arg3:s32'
add 'p:co05/mesh_remove mgmt_mesh_remove'
add 'p:co05/rm_adv hci_remove_adv_instance instance=$arg2:u8'
P=/sys/module/bluetooth/parameters/scratch_fail_mesh_add
if [ -e "$P" ]; then
	echo "$N" > "$P"
	echo "scratch_fail_mesh_add = $(cat "$P")"
else
	echo "scratch_fail_mesh_add: not in this kernel"
fi
echo 1 > "$T/events/co05/enable"
echo 1 > "$T/tracing_on"
"$@"
rc=$?
echo 0 > "$T/tracing_on"
echo "scratch_fail_mesh_add after the run = $(cat "$P" 2>/dev/null)"
echo "=== kprobe trace begin ==="
cat "$T/trace"
echo "=== kprobe trace end ==="
exit $rc
