#!/bin/bash
# ci-run-images.sh — for each run id given, print the run's runner image and version
# (read from the first job's log) and the run's conclusion.
# usage: scripts/ci-run-images.sh <run-id>...
set -u
repo=ivoitovych/qca9377-bt-hang
for id in "$@"; do
	concl=$(gh run view "$id" --repo "$repo" --json conclusion,createdAt --jq '.createdAt + " " + .conclusion')
	job=$(gh run view "$id" --repo "$repo" --json jobs --jq '.jobs[0].databaseId')
	img=$(gh run view "$id" --repo "$repo" --job "$job" --log 2>&1 | grep -m2 -E 'Image: |Version: [0-9]{8}\.' | sed 's/^.*Z //' | tr '\n' ' ')
	printf '%s %s %s\n' "$id" "$concl" "$img"
done
