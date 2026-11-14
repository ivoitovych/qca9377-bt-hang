#!/bin/bash
# build-bluez.sh - build tools/mgmt-tester, tools/mesh-tester, tools/test-runner from the bluez clone
# (HEAD = master + CO-38 series). No sanitizers. -j4. Binaries to CO-38/bin/.
set -u
ulimit -c 0
W=/root/exp/agent-work/lane3-mgmt-20261114
B=$W/bluez
mkdir -p "$W/CO-38/bin" "$W/CO-38/logs"
cd "$B" || exit 2
if [ ! -f config.status ]; then
	./bootstrap > "$W/CO-38/logs/bluez-bootstrap.log" 2>&1 || { echo "bootstrap failed"; exit 2; }
	./configure --enable-testing --enable-experimental --enable-debug \
		--disable-manpages --disable-systemd --disable-cups \
		--disable-obex --disable-udev --disable-client \
		--disable-datafiles > "$W/CO-38/logs/bluez-configure.log" 2>&1 || { echo "configure failed"; tail -n 5 "$W/CO-38/logs/bluez-configure.log"; exit 2; }
fi
nice -n 10 make -j4 tools/mgmt-tester tools/mesh-tester tools/test-runner > "$W/CO-38/logs/bluez-make.log" 2>&1
rc=$?
echo "make rc=$rc"
grep -E "warning|error" "$W/CO-38/logs/bluez-make.log" | tail -n 30
if [ "$rc" = 0 ]; then
	cp tools/mgmt-tester "$W/CO-38/bin/mgmt-tester-series"
	cp tools/mesh-tester "$W/CO-38/bin/mesh-tester-series"
	cp tools/test-runner "$W/CO-38/bin/test-runner"
	sha256sum "$W/CO-38/bin/mgmt-tester-series" "$W/CO-38/bin/mesh-tester-series" "$W/CO-38/bin/test-runner"
fi
exit $rc
