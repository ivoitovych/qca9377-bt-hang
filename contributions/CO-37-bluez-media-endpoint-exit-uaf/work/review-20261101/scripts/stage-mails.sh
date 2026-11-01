#!/bin/bash
# Copy the rebased mails into the project clone (the CI container sees
# only the project, the cache and the tree), in send order, numbered.
set -eu
W=/root/exp/agent-work/co23-co37-review-20261101
D=$W/proj/tmp/mails
i=1
for m in "$W"/mails/co23/0*.patch "$W"/mails/co37/0*.patch; do
	n=$(printf '%02d' "$i")
	cp "$m" "$D/$n-$(basename "$m")"
	i=$((i + 1))
done
ls -l "$D"
sha256sum "$D"/*.patch
