#!/bin/bash
# apply-check.sh <tag> <line> : does the pair apply onto today's tag?  6.x: git am of the final backport files
# (plain, no 3-way); 7.3.y: cherry-pick -x of the two mainline commits. Log: logs/apply-<tag>.log
set -u
TAG=${1:?usage}; LINE=${2:?usage}
R=/root/exp/qca9377-bt-hang
W=/root/exp/agent-work/lane5-status-stable-20261114/co35
KR=/root/exp/agent-work/lane5-status-stable-20261114/k/repo
T=/root/exp/agent-work/lane5-status-stable-20261114/k/wt-$TAG
PK=$R/contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261102
LOG=$W/logs/apply-$TAG.log
G=(git -C "$T" -c user.name=check -c user.email=check@example.com)
mkdir -p "$W/logs"
if [[ ! -e $T ]]; then git -C "$KR" worktree add --detach "$T" "$TAG" > /dev/null || exit 2; fi
"${G[@]}" reset -q --hard "$TAG" || exit 2
{
	echo "tag $TAG = $(git -C "$T" rev-parse HEAD)  $(date -u '+%F %T') UTC"
	if [[ $LINE == 7.3.y ]]; then
		"${G[@]}" cherry-pick -x 608e0b7a675b2affbbf38167cad0fa63d8e064f7 32d86e048d8efedb7aa6cbbd3c36c3c435401c92
		echo "cherry-pick rc=$?"
		"${G[@]}" log --format='%h %s' -n 3
		"${G[@]}" cherry-pick -x 5874f8d03268d34189c6c12c56586b64d26a8bcc
		echo "sci cherry-pick rc=$?"
		"${G[@]}" log --format='%h %s' -n 4
	else
		"${G[@]}" am "$PK/$LINE"/0001-*.patch "$PK/$LINE"/0002-*.patch
		echo "git am rc=$?"
		"${G[@]}" log --format='%h %s' -n 3
	fi
	"${G[@]}" diff --stat "$TAG"
} > "$LOG" 2>&1
echo "APPLY-DONE $TAG" >> "$LOG"
