#!/bin/bash
# SHA256SUMS of the folder (not the shared-object clone k/, not the images).
cd /root/exp/agent-work/lane4-bluez-20261114/stable-20261114 || exit 2
: > SHA256SUMS
{
    find . -type f -not -path './k/*' -not -path './img/*' -not -name SHA256SUMS
} | sort | while read -r f; do
    nice -n 19 ionice -c 3 sha256sum "$f" >> SHA256SUMS
done
sha256sum img/* >> SHA256SUMS
wc -l SHA256SUMS
