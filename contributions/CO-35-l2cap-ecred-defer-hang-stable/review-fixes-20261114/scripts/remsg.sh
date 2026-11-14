#!/bin/bash
# remsg.sh: re-make the reduced patches with the reworded note in the commit message of patch 1 (the code is
# unchanged: the new patch bodies are compared with the tested ones). Old files are kept in reduced-first-wording/.
set -u
W=/root/exp/agent-work/lane4-bluez-20261114/stable-20261114
K=$W/k
mkdir -p "$W/reduced-first-wording"
for pair in "v6.6.162 6.6.y 6x" "v6.12.117 6.12.y 6x" "v6.18.63 6.18.y 6x" "v7.3.4 7.3.y 73"; do
	set -- $pair
	TAG=$1; LINE=$2; M=$3
	T=$W/wt-remsg-$TAG
	rm -rf "$T"
	git -C "$K" worktree prune
	git -C "$K" worktree add --detach "$T" "$TAG" > /dev/null || exit 2
	p1=$(ls "$W/reduced/$LINE"/0001-*.patch)
	p2=$(ls "$W/reduced/$LINE"/0002-*.patch)
	ID=(-c user.name="Iaroslav Voitovych" -c user.email="yaroslav.voytovych@gmail.com")
	git -C "$T" "${ID[@]}" am "$p1" > /dev/null || exit 2
	git -C "$T" "${ID[@]}" commit -q --amend -F "$W/msg-reduced-$M.txt" || exit 2
	git -C "$T" "${ID[@]}" am "$p2" > /dev/null || exit 2
	mkdir -p "$W/reduced-first-wording/$LINE"
	cp "$p1" "$p2" "$W/reduced-first-wording/$LINE/"
	rm -f "$W/reduced/$LINE"/*.patch
	git -C "$T" format-patch -2 -o "$W/reduced/$LINE" > /dev/null
	git -C "$K" worktree remove --force "$T"
	echo "$LINE done"
done
