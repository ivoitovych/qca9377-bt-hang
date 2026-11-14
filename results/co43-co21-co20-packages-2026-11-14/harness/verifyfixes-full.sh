#!/bin/bash
# verifyfixes-full.sh <patch>: the bot's own VerifyFixes script (action-ci scripts/verify_fixes.sh) on the
# patch's message, in a repository that has mainline's complete commit history: a scratch repository of
# this work area whose object store borrows from the CO-43 work area's treeless clone of mainline
# (read-only). The message is committed (empty tree) on top of mainline master; VerifyFixes reads only
# the message, the target's existence and subject, and the ancestry. Two messages: as in the package
# (no Signed-off-by) and with a Signed-off-by after the Fixes: line, as the operator will add it.
# Runs in the bot's Docker image without network. Output: task3/logs/verifyfixes-full-<name>.txt
set -u
l=/root/exp/agent-work/lane1-btusb-20261114
t=$l/task3
src=/root/exp/agent-work/co43-ea-send-20261113/cache/linux-treeless
patch=${1:?usage}
name=$(basename "$patch" .patch)
r=$t/tmp/vf-repo
v=$t/tmp/vf-$name
o=$t/logs/verifyfixes-full-$name.txt
img=bluez-action-ci:c7d077f185cd
mkdir -p "$v"
if [ ! -d "$r/.git" ]; then
	git init -q "$r" || exit 2
	echo "$src/.git/objects" >"$r/.git/objects/info/alternates"
	git -C "$r" update-ref refs/heads/master "$(git -C "$src" rev-parse master)" || exit 2
fi
git mailinfo "$v/msg" "$v/patch" <"$patch" >"$v/info"
subj=$(sed -n 's/^Subject: //p' "$v/info")
{ echo "$subj"; echo; cat "$v/msg"; } >"$v/msg-nosob.txt"
sed '/^Fixes: /a Signed-off-by: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>' "$v/msg-nosob.txt" >"$v/msg-sob.txt"
empty=4b825dc642cb6eb9a060e54bf8d69288fbee4904
c1=$(git -C "$r" -c user.name="Iaroslav Voitovych" -c user.email=yaroslav.voytovych@gmail.com commit-tree "$empty" -p master -F "$v/msg-nosob.txt") || exit 2
c2=$(git -C "$r" -c user.name="Iaroslav Voitovych" -c user.email=yaroslav.voytovych@gmail.com commit-tree "$empty" -p master -F "$v/msg-sob.txt") || exit 2
{
	echo "mainline master: $(git -C "$r" log -1 --format='%H %cd %s' master)"
	for c in "$c1" "$c2"; do
		echo "== verify_fixes.sh master..$c ($(git -C "$r" log -1 --format=%B "$c" | grep -c '^Signed-off-by') Signed-off-by line(s))"
		docker run --rm --network none --volume "$l:$l" --volume "$src:$src:ro" --workdir "$r" --entrypoint bash "$img" \
			-c "git config --global --add safe.directory '*' && $t/cache/action-ci-bluez/scripts/verify_fixes.sh master..$c"
		echo "== exit $?"
	done
} >"$o" 2>&1
cat "$o"
