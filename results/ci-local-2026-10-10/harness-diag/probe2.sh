#!/bin/bash
# Differential control: bt-server-bredr (no crypto in btdev_create) against
# bt-server-bredrle and bt-server-le (bt_crypto_new, AF_ALG) on this host.
R=/home/user/qca9377-bt-hang; W=$R/tmp/functional-repeat/20261011T125340Z-pair_bredr-diag/work/src
H=$R/tmp/ci-local-research/harness-diag; S=$H/srv2; rm -rf $S; mkdir -p $S
date -u +%H:%M:%S; uname -r
ASAN_OPTIONS=detect_leaks=0 $W/emulator/btvirt --server=$S > $H/btvirt2.log 2>&1 &
BTV=$!; for i in $(seq 1 50); do [[ -S $S/bt-server-mon ]] && break; sleep 0.1; done
for srv in bt-server-bredr bt-server-bredrle bt-server-le; do
python3 -I - "$S/$srv" <<'PY'
import socket, sys, time
p = sys.argv[1]; name = p.rsplit("/", 1)[1]
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.settimeout(3); s.connect(p)
time.sleep(0.2)
try:
    t0 = time.time(); s.sendall(bytes([0x01, 0x01, 0x10, 0x00]))
    d = s.recv(64); print("%-17s reply after %.3fs: %s" % (name, time.time() - t0, d.hex(" ")))
except socket.timeout: print("%-17s no reply in 3 s" % name)
except OSError as e: print("%-17s %s" % (name, e))
PY
done
kill -0 $BTV 2>/dev/null && echo "btvirt still alive (pid $BTV)"; kill $BTV; wait $BTV 2>/dev/null
echo "btvirt log:"; cat $H/btvirt2.log
echo "--- AF_ALG on this host"; python3 -I -c "
import socket
for fam in ('AF_ALG',):
    try: socket.socket(socket.AF_ALG, socket.SOCK_SEQPACKET, 0); print(fam, 'socket ok')
    except OSError as e: print(fam, e)
"
echo "--- kernel config evidence"; ls /boot/config-* /proc/config.gz 2>&1 | head -2; grep -c . /proc/crypto 2>/dev/null; grep -m3 "^name" /proc/crypto 2>/dev/null
