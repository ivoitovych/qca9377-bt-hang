#!/bin/bash
# build-kernel.sh <name> <srcdir> <config fragments...>
# Builds <srcdir> into $WORK/build-<name> from x86_64_defconfig plus the
# given fragments. Fails if make fails; a bzImage left over from an
# earlier build is not accepted as success.
set -eo pipefail
WORK=${WORK:-/home/user/work}
name=$1; src=$2; shift 2
out=$WORK/build-$name
mkdir -p "$out"
export CCACHE_DIR=$WORK/ccache CCACHE_BASEDIR=$WORK CCACHE_NOHASHDIR=1 \
	CCACHE_SLOPPINESS=time_macros,include_file_mtime,include_file_ctime
cd "$src"
rm -f "$out/arch/x86/boot/bzImage"
make O="$out" x86_64_defconfig >/dev/null
scripts/kconfig/merge_config.sh -m -O "$out" "$out/.config" "$@" >/dev/null
make O="$out" olddefconfig >/dev/null
if ! make O="$out" CC="ccache gcc" -j"$(nproc)" bzImage > "$out/make.log" 2>&1; then
	grep -E "error|Error" "$out/make.log" | tail -20
	echo "FAILED $name"
	exit 1
fi
grep -E "warning:|Kernel: " "$out/make.log" || true
test -f "$out/arch/x86/boot/bzImage"
echo "BUILT $name $(git -C "$src" log --oneline -1)"
