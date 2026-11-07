#!/bin/bash
# build-bluez.sh - build tools/mgmt-tester (and tools/test-runner) from the
# BlueZ worktree /root/exp/agent-work/research-mesh/bluez (master 14bd6ab65
# + the research AdvDur cases). No sanitizers, no mesh/btpclient (no ell).
# Copies the binaries to /root/exp/agent-work/research-mesh/bin/.
set -u
R=/root/exp/agent-work/research-mesh
B=$R/bluez
mkdir -p "$R/bin" "$R/logs"
echo "== bluez build start $(date '+%F %T')" | tee -a "$R/progress.log"
cd "$B" || exit 2
if [ ! -f config.status ]; then
	./bootstrap > "$R/logs/bluez-bootstrap.log" 2>&1 || { echo "bootstrap failed"; exit 2; }
	./configure --enable-testing --enable-experimental --enable-debug \
		--disable-manpages --disable-systemd --disable-cups \
		--disable-obex --disable-udev --disable-client \
		--disable-datafiles > "$R/logs/bluez-configure.log" 2>&1 || { echo "configure failed"; tail -n 5 "$R/logs/bluez-configure.log"; exit 2; }
fi
nice -n 10 make -j6 tools/mgmt-tester tools/test-runner > "$R/logs/bluez-make.log" 2>&1
rc=$?
echo "== bluez build end $(date '+%F %T') rc=$rc" | tee -a "$R/progress.log"
grep -E "warning|error" "$R/logs/bluez-make.log" | tail -n 20
if [ "$rc" = 0 ]; then
	cp tools/mgmt-tester "$R/bin/mgmt-tester-advdur"
	cp tools/test-runner "$R/bin/test-runner"
	sha256sum "$R/bin/mgmt-tester-advdur" "$R/bin/test-runner"
fi
exit $rc
