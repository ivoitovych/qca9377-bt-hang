#!/bin/bash
# pw-mbox.sh ID... — download each patchwork patch's mbox (as posted) into
# /root/exp/agent-work/research-mesh/mbox/<id>.mbox and print its sha256.
set -eu
dir=/root/exp/agent-work/research-mesh/mbox
mkdir -p "$dir"
for id in "$@"; do
	curl -fsSL -A "research-mesh/1.0" -o "$dir/$id.mbox" "https://patchwork.kernel.org/patch/$id/mbox/"
	sha256sum "$dir/$id.mbox"
done
