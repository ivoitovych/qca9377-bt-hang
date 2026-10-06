#!/bin/sh
# Run the test matrix for one kernel build.
# Usage: run-matrix.sh <main|diag> <build-name> [jobs]
#   main: reproducer scenarios (1 and 4 CPUs) + mgmt-tester + mesh-tester
#   diag: kmemleak scenarios (needs a CONFIG_DEBUG_KMEMLEAK build with the
#         mesh_send_test_delay_ms knob)
# Environment: WORK  = directory holding build-<name>/ kernel builds
#              BLUEZ = configured and built BlueZ tree containing
#                      tools/mesh-leak-check (see build-repro.sh)
# Exits non-zero if any run does; mesh-tester exits 1 when cases fail.
set -u
KIND=$1; NAME=$2; JOBS=${3:-2}
WORK=${WORK:-/home/user/work}
export BLUEZ=${BLUEZ:-$WORK/bluez}
HERE=$(cd "$(dirname "$0")" && pwd)
IMG=$WORK/build-$NAME/arch/x86/boot/bzImage
LOGS=$HERE/logs/$NAME
REPRO=$BLUEZ/tools/mesh-leak-check
mkdir -p "$LOGS"

list() {
	if [ "$KIND" = main ]; then
		for adv in legacy ext; do
			for sc in baseline offline offline-busy enomem \
						enomem-busy close-reuse busy-drain; do
				echo "1 $sc-$adv-1cpu $REPRO $sc $adv"
			done
			echo "4 offline-$adv-4cpu $REPRO offline $adv"
			echo "4 enomem-$adv-4cpu $REPRO enomem $adv"
		done
		echo "1 mgmt-tester-1cpu tools/mgmt-tester -q"
		echo "1 mesh-tester-1cpu tools/mesh-tester -q"
	else
		# plain: scan only; shrink: shrink slab caches before each scan
		for sc in enetdown enomem enodev; do
			for adv in legacy ext; do
				echo "1 kmemleak-$sc-$adv-plain $REPRO kmemleak-$sc $adv plain"
				echo "1 kmemleak-$sc-$adv-shrink $REPRO kmemleak-$sc $adv shrink"
			done
		done
	fi
}

if list | xargs -P "$JOBS" -L 1 sh -c \
	'cpus=$1; tag=$2; shift 2; "'"$HERE"'/run-vm.sh" "'"$IMG"'" "$cpus" "'"$LOGS"'/$tag.log" "$@"' sh
then
	echo "all runs exited 0"
else
	echo "some runs exited non-zero: see rc=/cmd=/splat= above"
	exit 1
fi
