#!/bin/bash
# ci-local-publish.sh — copy the readable part of a ci-local.sh (or
# bluez-tester-compare.sh, functional-repeat.sh) run directory from tmp/ into a
# tracked results directory, with every e-mail address but the author's and
# the lists' replaced by <address elided>. tmp/ is ignored and vanishes with
# the container; what the results file cites must be tracked.
#
#   scripts/ci-local-publish.sh [--all] <run-dir> <dest-dir>
#
# --all copies every regular file (the patchwork JSON and survey text of a
# research directory, for instance), still with the addresses elided.
# Otherwise copied: summary.txt, run.log, *.classified.txt, *.findings, *.bot-view.txt,
# checkpatch.txt, gitlint.txt, am*.err, *.result, *.verdicts, and the stderr of
# a failed configure or make (configure.err / make.err whose run did not exit
# 0). The full build logs stay in tmp/: megabytes of compiler output that the
# findings files already summarise. Files over 2 MB are truncated to their
# first 2 MB with a note. Prints what it copied. Exit 2 on a missing directory.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALL=0
[[ "${1:-}" == "--all" ]] && { ALL=1; shift; }
SRC="${1:?usage: ci-local-publish.sh [--all] <run-dir> <dest-dir>}"
DEST="${2:?usage: ci-local-publish.sh [--all] <run-dir> <dest-dir>}"
[[ -d "$SRC" ]] || { echo "ci-local-publish: no such run directory: $SRC" >&2; exit 2; }
mkdir -p "$DEST" || exit 2
KEEP="$(git -C "$REPO" config user.email 2>/dev/null || echo yaroslav.voytovych@gmail.com)"
LIMIT=$((2 * 1024 * 1024))

elide() {   # elide <in> <out>
	python3 -I - "$1" "$2" "$KEEP" "$LIMIT" <<'PY'
import re, sys
src, dst, keep, limit = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
data = open(src, "rb").read()
note = b""
if len(data) > limit:
    data = data[:limit]; note = b"\n[truncated by ci-local-publish.sh: first 2 MB kept]\n"
text = data.decode("utf-8", errors="replace")
LISTS = re.compile(r"^(linux-[a-z0-9-]+|stable|netdev|patches|patchwork-bot)(\+[a-z]+)?@(vger\.kernel\.org|kernel\.org|lists\.linux\.dev)$")
def repl(m):
    a = m.group(0)
    # kept: the author's own address and the lists' and the patchwork bot's;
    # a person's kernel.org address is a person's address and goes
    if a.lower() == keep.lower() or LISTS.match(a.lower()):
        return a
    return "<address elided>"
text = re.sub(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", repl, text)
open(dst, "wb").write(text.encode("utf-8") + note)
PY
}

n=0
while IFS= read -r -d '' f; do
	rel="${f#"$SRC"/}"
	if (( ALL )); then
		mkdir -p "$DEST/$(dirname "$rel")"; elide "$f" "$DEST/$rel"; n=$((n + 1)); continue
	fi
	case "$rel" in
	work/*) continue ;;
	summary.txt|run.log|*.classified.txt|*.findings|*.bot-view.txt|checkpatch.txt|gitlint.txt|am.err|am-bluetooth-next.err|*.result|*.verdicts|*.out) ;;
	*.configure.err|*.make.err)
		# only when that step failed: its .out sibling ends with "exit status N"
		rc="$(tail -1 "$f" 2>/dev/null | grep -oE 'exit status [0-9]+' | awk '{print $3}')"
		[[ -n "$rc" && "$rc" != 0 ]] || continue ;;
	*.log) [[ "$rel" == *tester*.log || "$rel" == *.base.*.log || "$rel" == *.patched.*.log ]] || continue ;;
	*) continue ;;
	esac
	case "$rel" in *.out) [[ "$rel" == *pytest.out || "$rel" == base.*.out || "$rel" == patched.*.out || "$rel" == checkpatch.*.out ]] || continue ;; esac
	mkdir -p "$DEST/$(dirname "$rel")"
	elide "$f" "$DEST/$rel"
	n=$((n + 1))
done < <(find "$SRC" -type f -print0 | sort -z)
echo "ci-local-publish: $n file(s) from ${SRC#"$REPO"/} to ${DEST#"$REPO"/}"
