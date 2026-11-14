#!/bin/bash
# Project clone (to run bot-ci-local.sh from), own cache (action-ci-bluez, ell), BlueZ master fetched now.
set -eu
W=/root/exp/agent-work/co44-send-20261113
P=/root/exp/qca9377-bt-hang
mkdir -p $W/logs $W/cache
[[ -d $W/project ]] || git clone --quiet $P $W/project
if [[ ! -d $W/cache/action-ci-bluez ]]; then
	git clone --quiet $P/cache/action-ci-bluez $W/cache/action-ci-bluez
	git -C $W/cache/action-ci-bluez remote set-url origin "$(git -C $P/cache/action-ci-bluez remote get-url origin)"
fi
git -C $W/cache/action-ci-bluez fetch --quiet origin
if [[ ! -d $W/cache/ell ]]; then
	git clone --quiet $P/cache/ell $W/cache/ell
	git -C $W/cache/ell remote set-url origin "$(git -C $P/cache/ell remote get-url origin)"
fi
git -C $W/cache/ell fetch --quiet origin
if [[ ! -d $W/bluez ]]; then
	git clone --quiet --reference $P/cache/bluez-upstream https://git.kernel.org/pub/scm/bluetooth/bluez.git $W/bluez
fi
git -C $W/bluez fetch --quiet origin
{
	date -u '+fetched %F %TZ'
	echo "bluez origin/master $(git -C $W/bluez rev-parse origin/master) $(git -C $W/bluez log -1 --format='%cI %s' origin/master)"
	echo "action-ci-bluez origin/main $(git -C $W/cache/action-ci-bluez rev-parse origin/main)  (project cache: $(git -C $P/cache/action-ci-bluez rev-parse origin/main))"
	echo "ell origin/master $(git -C $W/cache/ell rev-parse origin/master)"
} | tee $W/logs/bluez-tips.txt
