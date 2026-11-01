#!/bin/bash
# Stage the final CO-23 mails and the retitled CO-37 mails (fix 1's
# subject shortened for the bot's 80-column title rule) into the project
# clone, in send order.
set -eu
W=/root/exp/agent-work/co23-co37-review-20261101
D=$W/proj/tmp/mails-retitled
mkdir -p "$D"
i=1
for m in "$W"/mails/final-co23/0*.patch "$W"/mails/final-co37-retitled/0*.patch; do
	n=$(printf '%02d' "$i")
	cp "$m" "$D/$n-$(basename "$m")"
	i=$((i + 1))
done
sha256sum "$D"/*.patch
