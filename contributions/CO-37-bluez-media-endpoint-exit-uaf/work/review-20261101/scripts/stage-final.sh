#!/bin/bash
# Copy the final rebased mails into the project clone (the CI container
# sees only the project, the cache and the tree), in send order.
set -eu
W=/root/exp/agent-work/co23-co37-review-20261101
D=$W/proj/tmp/mails-final
mkdir -p "$D"
i=1
for m in "$W"/mails/final-co23/0*.patch "$W"/mails/final-co37/0*.patch; do
	n=$(printf '%02d' "$i")
	cp "$m" "$D/$n-$(basename "$m")"
	i=$((i + 1))
done
sha256sum "$D"/*.patch
