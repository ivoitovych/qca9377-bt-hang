#!/bin/bash
# the packaging commit on a local branch (nothing is pushed)
set -eu
cd $WORKDIR/pkg/packaging
git checkout -q -B lp-NNNNNNN-journalctl-many-files-noble
git reset -q --hard e9f476fd65e92a37b460cbb0af458f562a3e0ce2
git clean -fdq debian
python3 -I $WORKDIR/bin/make-packaging-commit.py
git add debian/patches debian/changelog
export GIT_AUTHOR_NAME=$(git -C $REPO config user.name) GIT_AUTHOR_EMAIL=$(git -C $REPO config user.email)
export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL
git commit -q -F - <<'EOT'
d/p/lpNNNNNNN-*: cherry-pick two upstream fixes for journalctl on many journal files (LP: #NNNNNNN)

Upstream commits 99e6f682d3 and 51b2bcf835 (v256) stop sd-journal from
calling fstat() on every open journal file for every entry it returns.
Reading a journal that spans many files was slow in proportion to the
number of files; with these two patches the system calls are gone.

Bug: https://github.com/systemd/systemd/issues/31486
EOT
git log --oneline -3
git show --stat HEAD
