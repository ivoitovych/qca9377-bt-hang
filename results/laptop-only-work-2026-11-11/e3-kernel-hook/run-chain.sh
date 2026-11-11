#!/bin/bash
# Host-side orchestration of the container scenarios (Docker only; nothing passed through, no
# privileges). Intermediate images are committed so each scenario starts from a real earlier state.
W=/root/exp/agent-work/laptop-e3-autobuild-20261111
P=/root/exp/qca9377-bt-hang
mkdir -p $W/logs
OPTS="-v $W:/w:ro -v $W:$W:ro -v $P:/proj:ro -v $W/logs:/out"
step() { "$W/plog.sh" "$*"; }
runc() { # runc <name> <image> <script> [docker opts...]
	local name=$1 img=$2 scr=$3; shift 3
	docker rm -f $name >/dev/null 2>&1
	docker run --name $name "$@" $OPTS $img /w/tests/$scr
	echo "docker run $name rc=$?"
}
want=${1:-all}
if [ "$want" = all ] || [ "$want" = s1 ]; then
	step "START s1 install 38 (network)"; runc e3-s1 e3-test-base:1 s1-install-38.sh
	docker commit e3-s1 e3-after38 >/dev/null; docker rm e3-s1 >/dev/null; step "END s1"
fi
if [ "$want" = all ] || [ "$want" = s2 ]; then
	step "START s2 install 42 no network"; runc e3-s2 e3-after38 s2-install-42-nonet.sh --network none
	docker commit e3-s2 e3-after42fail >/dev/null; docker rm e3-s2 >/dev/null; step "END s2"
fi
for s in s8-running-and-killswitch s9-rollback; do
	if [ "$want" = all ] || [ "$want" = "${s%%-*}" ]; then
		step "START $s"; runc e3-$s e3-after42fail $s.sh; docker rm e3-$s >/dev/null; step "END $s"
	fi
done
if [ "$want" = all ] || [ "$want" = s3 ]; then
	step "START s3 retry online"; runc e3-s3 e3-after42fail s3-retry-online.sh
	docker commit e3-s3 e3-after42ok >/dev/null; docker rm e3-s3 >/dev/null; step "END s3"
fi
for s in s4-noheaders s5-patch-fails s6-present-43; do
	if [ "$want" = all ] || [ "$want" = "${s%%-*}" ]; then
		step "START $s"; runc e3-$s e3-after38 $s.sh; docker rm e3-$s >/dev/null; step "END $s"
	fi
done
if [ "$want" = all ] || [ "$want" = s7 ]; then
	step "START s7 twice"; runc e3-s7 e3-after42ok s7-twice.sh; docker rm e3-s7 >/dev/null; step "END s7"
fi
