#!/bin/bash
# Inside the container: do the heap patch apply to a clean checkout of main at the revision used?
cd /work/src/v-e && git stash list >/dev/null 2>&1
git apply --check /repo/patches/systemd/journal-file-scaling/heap/*.patch && echo "heap patch applies to main"
