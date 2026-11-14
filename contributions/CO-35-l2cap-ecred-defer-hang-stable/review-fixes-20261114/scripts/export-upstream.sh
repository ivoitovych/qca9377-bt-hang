#!/bin/bash
# Export the two mainline commits (and the SCI fix) from lane 5's kernel repository (read only) as patches.
W=/root/exp/agent-work/lane4-bluez-20261114/stable-20261114
KR=/root/exp/agent-work/lane5-status-stable-20261114/k/repo
mkdir -p "$W/upstream"
for s in 608e0b7a675b2affbbf38167cad0fa63d8e064f7 32d86e048d8efedb7aa6cbbd3c36c3c435401c92 5874f8d03268d34189c6c12c56586b64d26a8bcc; do
	git -C "$KR" format-patch -1 --stdout "$s" > "$W/upstream/${s:0:12}.patch"
	echo "${s:0:12} $(git -C "$KR" log -1 --format=%s "$s")"
done
