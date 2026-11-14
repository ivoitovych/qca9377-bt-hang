#!/bin/bash
# Is each stable branch tip (released) the commit of the tag the packages were tested on?
W=/root/exp/agent-work/lane4-bluez-20261114/stable-20261114
K=$W/k
ST=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
exec > "$W/logs/tags-vs-tips.txt" 2>&1
echo "checked $(date -u '+%F %T') UTC"
for pair in "7.3 v7.3.4" "6.18 v6.18.63" "6.12 v6.12.117" "6.6 v6.6.162" "6.1 v6.1.192" "5.15 v5.15.225" "5.10 v5.10.274"; do
	set -- $pair
	tip=$(git ls-remote "$ST" "refs/heads/linux-$1.y" | cut -c1-12)
	tag=$(git -C "$K" rev-parse --short=12 "$2^{commit}")
	if [[ "$tip" == "$tag" ]]; then echo "linux-$1.y tip $tip == $2 ($tag)"; else echo "linux-$1.y tip $tip != $2 ($tag)"; fi
done
