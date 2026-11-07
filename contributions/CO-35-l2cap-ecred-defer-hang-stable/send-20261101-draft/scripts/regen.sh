#!/bin/bash
# regen.sh <tag> <line> : git am the package's two patches (send/<line>/) onto <tag> in wt/<tag> and write
# format-patch output (cover letter, --base) to drafts/<line>/. Leaves wt/<tag> at the am result.
set -u
TAG=${1:?usage}; LINE=${2:?usage}
R=/root/exp/qca9377-bt-hang
W=/root/exp/agent-work/co35/refresh-20261101
T=$W/wt/$TAG
S=$R/contributions/CO-35-l2cap-ecred-defer-hang-stable/send/$LINE
[[ -e $W/drafts/$LINE ]] && { echo "refusing: drafts/$LINE exists"; exit 2; }
git -C "$T" reset -q --hard "$TAG" || exit 2
git -C "$T" -c user.name="Iaroslav Voitovych" -c user.email=yaroslav.voytovych@gmail.com am "$S"/0001-*.patch "$S"/0002-*.patch || exit 3
git -C "$T" log --format='%h %s' -n 3
git -C "$T" format-patch --subject-prefix "PATCH $LINE" --cover-letter --base="$TAG" -o "$W/drafts/$LINE" "$TAG..HEAD"
git -C "$T" reset -q --hard "$TAG"
