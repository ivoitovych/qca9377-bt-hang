#!/bin/bash
# qemu-smp.sh - qemu wrapper for test-runner -q (research gates of
# 2026-10-05, gate 1b). test-runner boots the guest with "acpi=off
# pci=noacpi noapic"; with ACPI off the guest finds its CPUs only in the
# BIOS MP table, which lists one processor even with -smp 4
# (logs/gates-2026-10-05/run-b-try-btnext-kasan-smp4.log: "Processors: 1",
# "smp: Brought up 1 node, 1 CPU"). This wrapper drops those three words
# from the kernel command line (the -append argument) and adds -smp
# (QEMU_SMP, default 4); everything else is passed through unchanged.
set -u
args=()
for a in "$@"; do
	case "$a" in
	console=hvc0*)
		a="${a/ acpi=off pci=noacpi noapic/}"
		;;
	esac
	args+=("$a")
done
exec /usr/bin/qemu-system-x86_64 "${args[@]}" -smp "${QEMU_SMP:-4}"
