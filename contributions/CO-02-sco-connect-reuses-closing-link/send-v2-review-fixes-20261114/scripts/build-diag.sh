#!/bin/bash
# build-diag.sh : e123 (patches 1+2+3 + early park) with hang diagnostics: magic sysrq, hung task detector (45 s),
# workqueue watchdog, softlockup. Image tag e123d. Changes the config of the shared object dir (all other kernels are built).
W=/root/exp/agent-work/lane7-sco-20261114
OBJ=$W/build/obj
for s in MAGIC_SYSRQ DETECT_HUNG_TASK DEFAULT_HUNG_TASK_TIMEOUT WQ_WATCHDOG SOFTLOCKUP_DETECTOR BOOTPARAM_HUNG_TASK_PANIC DETECT_HUNG_TASK_BLOCKER MAGIC_SYSRQ_DEFAULT_ENABLE; do
	sed -i "/^CONFIG_$s=/d; /^# CONFIG_$s is not set/d" "$OBJ/.config"
done
{
	echo "CONFIG_MAGIC_SYSRQ=y"
	echo "CONFIG_MAGIC_SYSRQ_DEFAULT_ENABLE=0x1"
	echo "CONFIG_DETECT_HUNG_TASK=y"
	echo "CONFIG_DEFAULT_HUNG_TASK_TIMEOUT=45"
	echo "CONFIG_WQ_WATCHDOG=y"
	echo "CONFIG_SOFTLOCKUP_DETECTOR=y"
} >> "$OBJ/.config"
$W/scripts/build-kernel.sh e123d l7-e123
