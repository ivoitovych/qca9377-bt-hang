#!/bin/sh
# one l2cap-tester case inside a test-runner guest (the case name has spaces, so a wrapper is the command)
exec /root/exp/qca9377-bt-hang/cache/co02-bluez/tools/l2cap-tester -s "L2CAP Ext-Flowctl Server - Accept 2 Close 1"
