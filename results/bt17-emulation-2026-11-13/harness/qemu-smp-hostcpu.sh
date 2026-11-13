#!/bin/bash
# qemu-smp-hostcpu.sh - as tmp/mesh-tester-ci/qemu-smp.sh (drops "acpi=off pci=noacpi noapic"
# from -append, adds -smp), and adds "-cpu host" at the end, so that on this Ryzen host the
# guest kernel sees X86_FEATURE_ZEN (btusb's platform_is_ryzen()).
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
exec /usr/bin/qemu-system-x86_64 "${args[@]}" -smp "${QEMU_SMP:-4}" -cpu host
