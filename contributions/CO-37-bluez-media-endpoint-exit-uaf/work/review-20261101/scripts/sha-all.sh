#!/bin/bash
# SHA256SUMS of the work area's records: run logs and results, mails,
# scripts, fetched sources, results, compressed cores. Built trees
# (runs/*/src, runs/*/ell), the clones (repo, srcs, proj, cache,
# fetch/fedora-bluez) and the copied framework source are left out.
set -eu
W=/root/exp/agent-work/co23-co37-review-20261101
cd "$W"
find . -type f \
	-not -path './repo/*' -not -path './srcs/*/.git/*' \
	-not -path './proj/*' -not -path './cache/*' \
	-not -path './fetch/fedora-bluez/*' -not -path './ref-pytest_bluezenv/*' \
	-not -path './runs/*/src/*' -not -path './runs/*/ell/*' \
	-not -path './srcs/*/[!t]*' \
	-not -name SHA256SUMS -print0 |
	sort -z | xargs -0 sha256sum > SHA256SUMS
find ./srcs -maxdepth 2 -name '*.core.zst' -print0 | sort -z | xargs -0 -r sha256sum >> SHA256SUMS
find ./runs -path '*/src/*.core.zst' -print0 | sort -z | xargs -0 -r sha256sum >> SHA256SUMS
find ./proj/tmp -type f \( -name '*.patch' -o -name '*.log' -o -name '*.txt' -o -name '*.json' \) -not -path '*/work/*' -print0 | sort -z | xargs -0 -r sha256sum >> SHA256SUMS
sort -u -k2 SHA256SUMS -o SHA256SUMS
echo "$(wc -l < SHA256SUMS) files in $W/SHA256SUMS"
