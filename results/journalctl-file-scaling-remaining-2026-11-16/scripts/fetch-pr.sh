#!/bin/bash
# Read only: fetch PR #44579 of systemd/systemd (head, base, comments, reviews, commits) with plain GET requests.
W=$WORKDIR
D=$W/pr44579
mkdir -p $D
api() { curl -sSL --max-time 60 -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/systemd/systemd/$1" -o "$D/$2"; echo "$1 -> $2 $(wc -c < $D/$2) bytes"; }
api pulls/44579 pull.json
api pulls/44579/commits commits.json
api pulls/44579/files files.json
api pulls/44579/comments review-comments.json
api pulls/44579/reviews reviews.json
api issues/44579/comments issue-comments.json
api issues/44579/events events.json
cd $W/src/main
git fetch -q origin pull/44579/head:pr44579 2>&1 | tail -2
git log -1 --format='PR head: %H %cd %s' pr44579
git merge-base pr44579 origin/main 2>/dev/null
git log --oneline pr44579 -8
