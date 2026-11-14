#!/bin/bash
W=/root/exp/agent-work/lane5-status-stable-20261114/co22
KR=/root/exp/agent-work/lane5-status-stable-20261114/k/repo
git -C "$KR" worktree prune
for t in v7.3.4 v6.18.63 v6.12.117 v6.6.162 v6.1.192 v5.15.225 v5.10.274; do
	"$W/asus.sh" "$t"
	rm -rf "/root/exp/agent-work/lane5-status-stable-20261114/k/wt22-$t"
	git -C "$KR" worktree prune
done
echo CO22-ALL-DONE > "$W/logs/all.done"
