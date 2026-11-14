#!/bin/bash
# does the unadapted pair apply to 6.1.192, 5.15.225, 5.10.274 (lines not covered)? and does ab4eedb790ca exist there?
W=/root/exp/agent-work/lane5-status-stable-20261114/co35
KR=/root/exp/agent-work/lane5-status-stable-20261114/k/repo
for TAG in v6.1.192 v5.15.225 v5.10.274; do
	T=/root/exp/agent-work/lane5-status-stable-20261114/k/wt-old-$TAG
	LOG=$W/logs/apply-old-$TAG.log
	[[ -e $T ]] || git -C "$KR" worktree add --detach "$T" "$TAG" > /dev/null || continue
	G=(git -C "$T" -c user.name=check -c user.email=check@example.com)
	{
		echo "tag $TAG = $(git -C "$T" rev-parse HEAD)  $(date -u '+%F %T') UTC"
		"${G[@]}" cherry-pick -x 608e0b7a675b2affbbf38167cad0fa63d8e064f7
		echo "cherry-pick of 608e0b7a675b2 rc=$?"
		"${G[@]}" cherry-pick -x 32d86e048d8efedb7aa6cbbd3c36c3c435401c92
		echo "cherry-pick of 32d86e048d8ef (after the first) rc=$?"
		"${G[@]}" status --short | head -n 8
		"${G[@]}" cherry-pick --abort
		"${G[@]}" reset -q --hard "$TAG"
		echo "l2cap_chan_lock_conn in tree: $(grep -c l2cap_chan_lock_conn "$T/net/bluetooth/l2cap_core.c")"
		echo "l2cap_ecred_conn_rsp_defer in l2cap_core.c: $(grep -c __l2cap_ecred_conn_rsp_defer "$T/net/bluetooth/l2cap_core.c")"
	} > "$LOG" 2>&1
done
echo OLD-DONE > "$W/logs/apply-old.done"
