#!/bin/bash
# bot-co23.sh <out name> : the list bot's BlueZ checks on the two CO-23 mails, base vs patched
W=/root/exp/agent-work/lane2-sco-20261114
P=$W/project
cd "$P" || exit 2
exec "$P/scripts/bot-ci-local.sh" --space user --base 20ffd285b58facfd1f2478d159a5f941b09d5be1 \
	--kernel-image "$P/tmp/bzImage-p123" --out "$P/tmp/${1:?usage}" \
	"$P"/tmp/mails/co23/0001-*.patch "$P"/tmp/mails/co23/0002-*.patch
