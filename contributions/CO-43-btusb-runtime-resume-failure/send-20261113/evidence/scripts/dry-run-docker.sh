#!/bin/bash
# dry-run-docker.sh <package dir> <patch file> <--to/--cc arguments...>
# git send-email --dry-run of one patch, in a Docker container with no network (--network none),
# so nothing can leave even by mistake. The list bot's image has no git send-email, so the
# container chroots into this machine's root, mounted read-only, and runs its git 2.43 from there;
# only this work directory is writable (HOME is tmp/home, so no personal git config is read).
# It prints what git would send: the headers and the "Dry-OK. Log says" block with every RCPT TO.
# Output: <package dir>/dry-run.txt.
set -u
w=/root/exp/agent-work/co43-ea-send-20261113
img=${DRYRUN_IMAGE:-bluez-action-ci:60348956fc7b}
pkg=${1:?usage}
patch=${2:?usage}
shift 2
docker run --rm --network none --volume /:/host:ro --volume "$w:/host$w" \
	--entrypoint chroot "$img" /host /usr/bin/env -i HOME="$w/tmp/home" PATH=/usr/bin:/bin \
	GIT_CONFIG_NOSYSTEM=1 \
	/usr/bin/git -C "$pkg" -c user.name="Iaroslav Voitovych" -c user.email=yaroslav.voytovych@gmail.com \
	send-email --dry-run --confirm=never --smtp-server=smtp.gmail.com --smtp-server-port=587 \
	--smtp-encryption=tls --smtp-user=yaroslav.voytovych@gmail.com \
	--from="Iaroslav Voitovych <yaroslav.voytovych@gmail.com>" "$@" "$patch" >"$pkg/dry-run.txt" 2>&1
echo "exit $?" >>"$pkg/dry-run.txt"
cat "$pkg/dry-run.txt"
