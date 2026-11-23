#!/bin/bash
# apply-lines.sh <patch>... : apply-check the patches (stacked) on bluetooth-next and every live stable tip
set -u
R=/root/exp/qca9377-bt-hang
for rev in bluetooth-next/master stable/linux-7.3.y stable/linux-6.18.y stable/linux-6.12.y stable/linux-6.6.y stable/linux-6.1.y; do
	"$R/tmp/kernel-readiness-20261122/apply-check.sh" "$R/cache/linux" "$rev" patches "$@"
done
