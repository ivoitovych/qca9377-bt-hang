#!/bin/bash
# export-kernel-review.sh — the reviewer package for the held kernel patch, as
# plain files, taken from the held branch without checking it out:
#   the patch, patches/kernel/README.md (every check and its result), and the
#   EX-044 exhibit the finding rests on, plus a one-page brief for the reviewer.
# Nothing is pushed anywhere; the operator hands the directory over privately.
#
#   scripts/export-kernel-review.sh            writes tmp/review-kernel-0001/
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BR="${BT_HELD_BRANCH:-kernel/mgmt-flush-status}"
OUT="$REPO/tmp/review-kernel-0001"
rm -rf "$OUT"; mkdir -p "$OUT"
for f in $(git -C "$REPO" ls-tree -r --name-only "$BR" -- patches/kernel evidence/exhibits | grep -E 'patches/kernel/|exhibits/044-'); do
	mkdir -p "$OUT/$(dirname "$f")"
	git -C "$REPO" show "$BR:$f" > "$OUT/$f"
done
cat > "$OUT/REVIEW-BRIEF.md" <<'EOF'
# Review request — one kernel patch, net/bluetooth/mgmt.c

**What is asked.** Read the patch as a Bluetooth maintainer would, and as the
list's automated reviewer (Sashiko) will: is the analysis in the commit message
correct, is the one-line fix the right fix, is anything missing or wrong in the
trailers, and would you apply it. Findings of any size are wanted; "no
finding" is also an answer.

**Files.**
- `patches/kernel/0001-*.patch` — the patch, in `git format-patch` form.
- `patches/kernel/README.md` — the defect, where it came from, stable
  exposure, and every check done so far with its result (apply at six tips,
  full module builds at bluetooth-next and linux-6.1.y, checkpatch, runtime
  plan).
- `evidence/exhibits/044-*.md` — the capture the finding rests on: the kernel
  answering a flushed Start Discovery with Command Status Success, decoded
  from a btsnoop, command and verbatim output.

**Context, public.** The project is https://github.com/ivoitovych/qca9377-bt-hang
(a QCA9377 controller investigation). Two BlueZ patches from it are already in
BlueZ master (`a734b0605`, `0bed9886c`, 2026-09-21). This kernel patch is not
public yet and will be mailed to linux-bluetooth after review; please keep
the files private until then.

**Not asked.** Style beyond what checkpatch reports; the controller fault the
project is about (separate, unresolved, not in these files).
EOF
find "$OUT" -type f | sed "s|$OUT/||" | sort
echo "-> $OUT"
