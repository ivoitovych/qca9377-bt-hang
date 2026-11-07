#!/bin/bash
# sha256-all.sh - SHA256SUMS of the evidence in this area (logs, images'
# commit files, mboxes, cite files, patch, tester binary), paths relative.
set -u
R=/root/exp/agent-work/research-mesh
cd "$R" || exit 2
find logs mbox evidence patch-co12 img bin -type f ! -name 'bzImage-*' -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
sha256sum img/bzImage-* >> SHA256SUMS
grep -c "" SHA256SUMS
