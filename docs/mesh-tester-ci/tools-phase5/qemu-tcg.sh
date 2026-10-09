#!/bin/sh
# qemu wrapper for test-runner -q: force the TCG accelerator (software emulation),
# as the bot's qemu ran before its action passed /dev/kvm to docker (2026-09-15).
# test-runner hardcodes "-machine type=q35,accel=kvm:tcg"; rewrite that one argument.
args=""
for a in "$@"; do
	case "$a" in
	type=q35,accel=kvm:tcg*) a="type=q35,accel=tcg${a#type=q35,accel=kvm:tcg}" ;;
	esac
	args="$args \"$a\""
done
eval exec /usr/bin/qemu-system-x86_64 $args
