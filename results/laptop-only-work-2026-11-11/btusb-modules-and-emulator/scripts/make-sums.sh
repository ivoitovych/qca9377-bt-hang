#!/bin/bash
# make-sums.sh - SHA256SUMS of the kept results of this work area: modules, patches, scripts, out, logs,
# img (not the build trees, the kernel tree, the project clone or the cache clones, which are sources
# or bulk). Writes SHA256SUMS in the work area; refuses to overwrite.
set -u
w=/root/exp/agent-work/laptop-btusb-modules-20261111
[ -e "$w/SHA256SUMS" ] && { echo "exists: $w/SHA256SUMS"; exit 2; }
cd "$w" || exit 2
find modules patches scripts out logs img project/out/botci-co21-run2 project/out/botci-co21-run3 project/out/mails operator-cold-boot-procedure.txt progress.log -type f -not -path "*/work/*" | sort | xargs sha256sum >SHA256SUMS
grep -c "" SHA256SUMS
