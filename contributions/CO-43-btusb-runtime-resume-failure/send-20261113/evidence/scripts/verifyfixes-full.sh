#!/bin/bash
# verifyfixes-full.sh: the bot's own VerifyFixes script (action-ci scripts/verify_fixes.sh) on E's
# commit message, in a repository with mainline's complete commit history (a treeless clone of
# github.com/torvalds/linux, cache/linux-treeless). The bot's run on the patched side has
# bluetooth-next history since 2023 only, where the 2009 Fixes: target does not exist.
# E's message is committed (git commit-tree, mainline's tree, no change) on top of mainline master:
# VerifyFixes reads only the message, the target's existence and subject, and the ancestry, and
# 7bee549e197c is an ancestor of mainline master as of bluetooth-next. Two messages: as in the
# package (no Signed-off-by yet), and with a Signed-off-by line added after the Fixes: line, as
# the operator will. Runs in the bot's Docker image, no network. Output: tmp/verifyfixes-full.txt
set -u
w=/root/exp/agent-work/co43-ea-send-20261113
r=$w/cache/linux-treeless
o=$w/tmp/verifyfixes-full.txt
img=bluez-action-ci:c7d077f185cd
mkdir -p "$w/tmp/vf"
git mailinfo "$w/tmp/vf/msg" "$w/tmp/vf/patch" <"$w/package/E/0001-Bluetooth-btusb-Anchor-a-deferred-URB-under-txlock.patch" >"$w/tmp/vf/info"
subj=$(sed -n 's/^Subject: //p' "$w/tmp/vf/info")
{ echo "$subj"; echo; cat "$w/tmp/vf/msg"; } >"$w/tmp/vf/E-msg.txt"
sed '/^Fixes: /a Signed-off-by: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>' "$w/tmp/vf/E-msg.txt" >"$w/tmp/vf/E-msg-sob.txt"
tree=$(git -C "$r" rev-parse 'master^{tree}') || exit 2
c1=$(git -C "$r" -c user.name="Iaroslav Voitovych" -c user.email=yaroslav.voytovych@gmail.com commit-tree "$tree" -p master -F "$w/tmp/vf/E-msg.txt") || exit 2
c2=$(git -C "$r" -c user.name="Iaroslav Voitovych" -c user.email=yaroslav.voytovych@gmail.com commit-tree "$tree" -p master -F "$w/tmp/vf/E-msg-sob.txt") || exit 2
git -C "$r" update-ref refs/ea/vf-e-nosob "$c1"
git -C "$r" update-ref refs/ea/vf-e-sob "$c2"
{
	echo "mainline master: $(git -C "$r" log -1 --format='%H %cd %s' master)"
	echo "Fixes target: $(git -C "$r" log -1 --format='%H %s' 7bee549e197c)"
	for c in "$c1" "$c2"; do
		echo "== verify_fixes.sh master..$c ($(git -C "$r" log -1 --format=%B "$c" | grep -c '^Signed-off-by') Signed-off-by line(s))"
		docker run --rm --network none --volume "$w:$w" --workdir "$r" --entrypoint bash "$img" \
			-c "git config --global --add safe.directory '*' && $w/cache/action-ci-bluez/scripts/verify_fixes.sh master..$c"
		echo "== exit $?"
	done
} >"$o" 2>&1
cat "$o"
