#!/bin/bash
# guest-kprobe-trace.sh - runs INSIDE the test-runner guest (qemu), never on the host.
#   tools/test-runner -k bzImage-v3final-leakfix-trace -- \
#       /root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/guest-kprobe-trace.sh "<mesh-tester -s filter>"
# Installs kprobe events on the mesh scheduling functions (the guest image is
# built with CONFIG_KPROBE_EVENTS, frag-fault-kprobe.config), runs the selected
# mesh-tester cases with debug output, then prints the trace buffer. This is
# the branch evidence for which way hci_cmd_sync_dequeue() went and which
# error mesh_send_start_complete() saw.
set -u
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

: > "$T/kprobe_events"
add 'p:mesh/dequeue_in hci_cmd_sync_dequeue func=$arg2:x64 data=$arg3:x64'
add 'r:mesh/dequeue_ret hci_cmd_sync_dequeue ret=$retval:u8'
add 'p:mesh/send_sync mesh_send_sync data=$arg2:x64'
add 'p:mesh/start_complete mesh_send_start_complete data=$arg2:x64 err=$arg3:s32'
add 'p:mesh/done_sync mesh_send_done_sync'
add 'p:mesh/send_cancel send_cancel'
add 'p:mesh/mesh_next mesh_next'
add 'p:mesh/cmd_sync_clear hci_cmd_sync_clear'
add 'p:mesh/mgmt_cleanup mgmt_cleanup'

echo "--- kprobe_events ---"
cat "$T/kprobe_events"
echo "--- symbols ---"
grep -w -E 'mesh_send_sync|mesh_send_start_complete|mesh_send_done_sync|send_cancel|mesh_next|hci_cmd_sync_dequeue|hci_cmd_sync_clear|mgmt_cleanup|mesh_send_sync_ptr' /proc/kallsyms

echo 1 > "$T/events/mesh/enable"
echo 1 > "$T/tracing_on"

/root/exp/qca9377-bt-hang/cache/bluez-upstream/tools/mesh-tester -d -s "$1"
rc=$?

echo 0 > "$T/tracing_on"
echo "=== kprobe trace begin ==="
cat "$T/trace"
echo "=== kprobe trace end ==="
exit $rc
