#!/bin/bash
# Positive control for the host side of the functional harness: does btvirt
# --server answer an H4 "Read Local Version Information" over its unix socket?
R=/home/user/qca9377-bt-hang; W=$R/tmp/functional-repeat/20261011T125340Z-pair_bredr-diag/work/src
H=$R/tmp/ci-local-research/harness-diag; S=$H/srv; rm -rf $S; mkdir -p $S
ASAN_OPTIONS=detect_leaks=0 $W/emulator/btvirt --server=$S > $H/btvirt.log 2>&1 &
BTV=$!; for i in $(seq 1 50); do [[ -S $S/bt-server-bredrle ]] && break; sleep 0.1; done
ls -la $S
python3 -I - "$S/bt-server-bredrle" <<'PY'
import socket, sys, time
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.settimeout(3); s.connect(sys.argv[1])
t0 = time.time(); s.sendall(bytes([0x01, 0x01, 0x10, 0x00]))   # H4 cmd, Read Local Version (0x1001), plen 0
try:
    d = s.recv(64); print("reply after %.3fs: %s" % (time.time() - t0, d.hex(" ")))
except socket.timeout:
    print("no reply in 3 s")
PY
kill $BTV; wait $BTV 2>/dev/null; echo "btvirt log:"; cat $H/btvirt.log
