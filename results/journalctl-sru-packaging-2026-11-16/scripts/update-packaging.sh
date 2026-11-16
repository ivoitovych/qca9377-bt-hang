#!/bin/bash
# Host side: rewrite the headers and the changelog entry, check the code hunks, amend the commit, regenerate the format-patch.
set -eu
B=$WORKDIR/bin
PK=$WORKDIR/pkg/packaging
R=$REPO
OLD=90a78feea721d7811dbad7cf04e2c7453aff3a1c
cd $PK
git checkout -q lp-NNNNNNN-journalctl-many-files-noble
python3 -I $B/update-packaging.py
python3 -I $B/check-hunks.py $OLD
export GIT_AUTHOR_NAME=$(git -C $R config user.name) GIT_AUTHOR_EMAIL=$(git -C $R config user.email)
export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL
git add debian/patches debian/changelog
git commit -q --amend --no-edit
git log --oneline -2
git rev-parse HEAD
rm -f $R/packaging/noble-lp-NNNNNNN/0001-*.patch
git format-patch -1 HEAD -o $R/packaging/noble-lp-NNNNNNN
