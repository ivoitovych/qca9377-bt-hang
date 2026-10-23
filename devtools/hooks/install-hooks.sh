#!/bin/bash
# install-hooks.sh — link the tracked git hooks into this checkout's .git/hooks (idempotent).
# A hook already there that is not our link is left alone and reported.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
G="$(git -C "$ROOT" rev-parse --git-path hooks)"
[[ "$G" = /* ]] || G="$ROOT/$G"
for h in pre-push; do
	want="../../devtools/hooks/$h"
	if [[ -L "$G/$h" && "$(readlink "$G/$h")" == "$want" ]]; then echo "$h: already linked"; continue; fi
	if [[ -e "$G/$h" ]]; then echo "$h: $G/$h exists and is not our link; left alone" >&2; continue; fi
	ln -s "$want" "$G/$h" && echo "$h: linked"
done
