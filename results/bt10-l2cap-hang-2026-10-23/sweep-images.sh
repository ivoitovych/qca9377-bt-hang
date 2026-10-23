#!/bin/bash
# sweep-images.sh - L2CAP hang: "L2CAP Ext-Flowctl Server - Accept 2 Close 1" on the kernels already
# built for CO-02 (tmp/co02-w2c/img), 4 vCPUs, 180 s limit each. Logs tmp/l2cap-hang/logs/sweep-*.
set -u
R=/root/exp/qca9377-bt-hang
I=$R/tmp/co02-w2c/img
L=$R/tmp/l2cap-hang/logs
mkdir -p "$L"
C="L2CAP Ext-Flowctl Server - Accept 2 Close 1"
for t in v4-smp st7.2v4-base-smp st6.18v4-base-smp 612-base-smp st6.6-base-smp u38w-pre-smp; do
	"$R/tmp/l2cap-hang/run-one.sh" "$I/bzImage-$t" "$L/sweep-$t.log" 180 4 "$C"
done
