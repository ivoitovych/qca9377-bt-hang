#!/bin/bash
# bot-ci-local.sh - the linux-bluetooth CI bot's own checks, in its own Docker image, on local mails,
# before a send.
#
#   kernel: scripts/bot-ci-local.sh --tree <kernel git tree> --base <commit> --bluez-commit <commit>
#                                   --out <dir> [options] <patch mail>...
#   BlueZ:  scripts/bot-ci-local.sh --space user --base <BlueZ commit> --out <dir>
#                                   [--kernel-image <bzImage>] [options] <patch mail>...
#   options: [--side both|patched|base] [--only NAME,...] [--history-since DATE]
#
# The bot that posts on linux-bluetooth patchwork runs github.com/bluez/action-ci (main) in a Docker
# image built FROM ghcr.io/pv/bluez-ci-image:latest. This script:
#  1. builds that image from cache/action-ci-bluez at origin/main (git archive | docker build), tagged
#     bluez-action-ci:<commit>; the base image's digest is recorded in tmp/bot-ci-local/;
#  2. prepares the trees as the bot's workspace has them, under <out>/work/<side>/: src with
#     origin/master = --base and, on the patched side, HEAD a --no-ff merge of the mails applied with
#     git am (HEAD^2 is the series, as in refs/pull/N/merge); ell (ELL master, fetched now, as the bot
#     clones it). Kernel: src is a --shared clone of --tree on the base side and, on the patched side, a
#     blobless clone of bluetooth-next with complete history since --history-since (for VerifyFixes);
#     bluez is BlueZ at --bluez-commit (the bot clones master). BlueZ: src is a --shared clone of
#     cache/bluez-upstream (default --tree);
#  3. runs scripts/bot-ci-local/harness.py in the image (--device /dev/kvm, the project mounted at the
#     same path): the bot's create_test_list_kernel() or create_test_list_user() and each test's own
#     code with dry_run, so nothing is posted, mailed or pushed;
#  4. for --side both: patched first, then base; every TestRunner_* pair through
#     scripts/compare-tester-verdicts.py and every tester log through scripts/kernel-report-scan.py.
# Output: <out>/<side>/{report.txt,verdicts.json,<test>.log,harness.log}, <out>/compare-*.txt,
# <out>/summary.txt. The base side runs only the tree checks (not CheckPatch, GitLint, SubjectPrefix,
# VerifyFixes, VerifySignedoff, IncrementalBuild).
# Committer of the applied mails: the mail's author (VerifySignedoff checks the committer too; the
# bot's own committer is its sync job, and its VerifySignedoff passes on other series).
# --kernel-image (BlueZ): TestFunctional boots that bzImage instead of having pytest-bluezenv clone and
# build bluetooth-next with doc/tester.config; give one built from the same tree with that config.
set -u
R=/root/exp/qca9377-bt-hang
A=$R/cache/action-ci-bluez
usage() { sed -n '4,9p' "$0"; exit 2; }
SPACE=kernel TREE= BASE= BLUEZC= OUT= SIDE=both ONLY= KIMG=
HISTORY_SINCE=2023-01-01
BTNEXT=https://git.kernel.org/pub/scm/linux/kernel/git/bluetooth/bluetooth-next.git
MAILS=()
while (( $# )); do
	case "$1" in
	--space) SPACE=$2; shift ;;
	--tree) TREE=$(realpath -e "$2") || usage; shift ;;
	--base) BASE=$2; shift ;;
	--bluez-commit) BLUEZC=$2; shift ;;
	--kernel-image) KIMG=$(realpath -e "$2") || usage; shift ;;
	--out) OUT=$2; shift ;;
	--side) SIDE=$2; shift ;;
	--only) ONLY=$2; shift ;;
	--history-since) HISTORY_SINCE=$2; shift ;;
	-*) echo "unknown option $1"; usage ;;
	*) m=$(realpath -e "$1") || usage; MAILS+=("$m") ;;
	esac
	shift
done
case "$SPACE" in
kernel) [[ -n "$TREE" && -n "$BLUEZC" && -z "$KIMG" ]] || usage ;;
user) [[ -z "$BLUEZC" ]] || usage; [[ -n "$TREE" ]] || TREE=$R/cache/bluez-upstream ;;
*) usage ;;
esac
[[ -n "$BASE" && -n "$OUT" && ${#MAILS[@]} -gt 0 ]] || usage
case "$SIDE" in both|patched|base) ;; *) usage ;; esac
mkdir -p "$OUT" || exit 2
OUT=$(realpath -e "$OUT")
[[ "$OUT" == "$R"/* ]] || { echo "refusing: --out must be inside $R (the container sees only the project)"; exit 2; }
[[ -z "$KIMG" || "$KIMG" == "$R"/* ]] || { echo "refusing: --kernel-image must be inside $R"; exit 2; }
BASE=$(git -C "$TREE" rev-parse --verify "$BASE^{commit}") || exit 2
if [[ "$SPACE" == kernel ]]; then
	BLUEZC=$(git -C "$R/cache/bluez-upstream" rev-parse --verify "$BLUEZC^{commit}") || exit 2
fi
log() { echo "$(date -u '+%F %T') $*" | tee -a "$OUT/summary.txt"; }

# 1. the image
AC=$(git -C "$A" rev-parse origin/main) || exit 2
IMG=bluez-action-ci:${AC:0:12}
if ! docker image inspect "$IMG" > /dev/null 2>&1; then
	log "building $IMG from bluez/action-ci $AC"
	git -C "$A" archive origin/main | docker build --pull -t "$IMG" - > "$OUT/docker-build.log" 2>&1 || { log "docker build FAILED (see docker-build.log)"; exit 2; }
	mkdir -p "$R/tmp/bot-ci-local"
	grep -m1 -o -E "FROM ghcr.io/pv/bluez-ci-image:latest@sha256:[0-9a-f]+" "$OUT/docker-build.log" > "$R/tmp/bot-ci-local/$IMG.base"
fi
log "image $IMG: action-ci $AC; base $(cat "$R/tmp/bot-ci-local/$IMG.base" 2>/dev/null || echo 'digest not recorded')"
git -C "$R/cache/ell" fetch --quiet origin || { log "ELL fetch FAILED"; exit 2; }
ELLC=$(git -C "$R/cache/ell" rev-parse origin/master)
log "space $SPACE; base $BASE ($(git -C "$TREE" log -1 --format=%s "$BASE")); ${BLUEZC:+BlueZ $BLUEZC; }ELL $ELLC${KIMG:+; kernel image ${KIMG#"$R"/}}"
for m in "${MAILS[@]}"; do log "mail ${m#"$R"/}"; done

# 2. a side's workspace
prepare() {   # prepare <side>
	local w=$OUT/work/$1
	[[ -e "$w" ]] && { log "refusing: $w exists (a new --out per run)"; return 1; }
	mkdir -p "$w/patch"
	if [[ "$SPACE" == kernel && "$1" == patched ]]; then
		# VerifyFixes walks from the series to each Fixes: target. The project's kernel repository has
		# holes in its commit history (a partial clone: 2026-10-27, "Could not read 10d97b74e2ee", a
		# mainline merge of 2026-04-12), which a deepening fetch cannot fill, so the patched side gets
		# its own blobless clone of bluetooth-next with complete history since HISTORY_SINCE.
		log "patched: blobless clone of bluetooth-next since $HISTORY_SINCE"
		git clone --quiet --filter=blob:none --shallow-since="$HISTORY_SINCE" --no-checkout --branch master "$BTNEXT" "$w/src" || return 1
		git -C "$w/src" cat-file -e "$BASE^{commit}" 2>/dev/null || { log "refusing: $BASE is not in bluetooth-next master since $HISTORY_SINCE"; return 1; }
	else
		git clone --quiet --shared --no-checkout "$TREE" "$w/src" || return 1
	fi
	git -C "$w/src" update-ref refs/remotes/origin/master "$BASE" || return 1
	git -C "$w/src" checkout --quiet -B master "$BASE" || return 1
	if [[ "$1" == patched ]]; then
		local an ae
		an=$(git mailinfo /dev/null /dev/null < "${MAILS[0]}" | sed -n 's/^Author: //p')
		ae=$(git mailinfo /dev/null /dev/null < "${MAILS[0]}" | sed -n 's/^Email: //p')
		git -C "$w/src" checkout --quiet -b pr || return 1
		git -C "$w/src" -c user.name="$an" -c user.email="$ae" am --quiet "${MAILS[@]}" || { git -C "$w/src" am --abort; log "git am FAILED"; return 1; }
		git -C "$w/src" checkout --quiet master || return 1
		git -C "$w/src" -c user.name="$an" -c user.email="$ae" merge --quiet --no-ff --no-edit pr || return 1
	fi
	if [[ "$SPACE" == kernel ]]; then
		git clone --quiet --shared --no-checkout "$R/cache/bluez-upstream" "$w/bluez" || return 1
		git -C "$w/bluez" checkout --quiet --detach "$BLUEZC" || return 1
	fi
	git clone --quiet --shared --no-checkout "$R/cache/ell" "$w/ell" || return 1
	git -C "$w/ell" checkout --quiet --detach "$ELLC" || return 1
}

# 3. one side in the image
run_side() {   # run_side <side>
	local w=$OUT/work/$1 o=$OUT/$1 rc
	local extra=()
	[[ "$SPACE" == kernel ]] && extra+=(--bluez "$w/bluez")
	[[ -n "$KIMG" ]] && extra+=(--kernel-image "$KIMG")
	[[ -n "$ONLY" ]] && extra+=(--only "$ONLY")
	mkdir -p "$o"
	log "$1: start"
	docker run --rm --device=/dev/kvm:/dev/kvm --volume "$R:$R" --workdir "$w" \
		--env PATH=/opt/llvm/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
		--env GIT_COMMITTER_NAME=local --env GIT_COMMITTER_EMAIL=local@users.noreply.github.com \
		--entrypoint python3 "$IMG" "$R/scripts/bot-ci-local/harness.py" \
		--side "$1" --space "$SPACE" --src "$w/src" --ell "$w/ell" --patch-root "$w/patch" \
		--out "$o" "${extra[@]}" "${MAILS[@]}" > "$o/harness.log" 2>&1
	rc=$?
	log "$1: done, $rc test(s) not PASS"
	sed -n '/^Test Summary/,$p' "$o/report.txt" | tee -a "$OUT/summary.txt"
}

# patched first: its patch-level checks report within minutes
for s in patched base; do
	[[ "$SIDE" == both || "$SIDE" == "$s" ]] || continue
	prepare "$s" || { log "$s: workspace FAILED"; exit 2; }
	run_side "$s"
done

# 4. the difference
if [[ "$SIDE" == both ]]; then
	for f in "$OUT"/patched/TestRunner_*.log; do
		[[ -f "$f" ]] || continue
		t=$(basename "$f" .log)
		[[ -f "$OUT/base/$t.log" ]] || { log "$t: no base log"; continue; }
		python3 -I "$R/scripts/compare-tester-verdicts.py" "$OUT/base/$t.log" "$f" > "$OUT/compare-$t.txt" 2>&1
		log "$t: $(grep -m1 -E '^not-passed sets identical' "$OUT/compare-$t.txt" || echo 'no comparison (see compare file)')"
	done
	if compgen -G "$OUT/*/TestRunner_*.log" > /dev/null; then
		python3 -I "$R/scripts/kernel-report-scan.py" "$OUT"/*/TestRunner_*.log > "$OUT/kernel-report-scan.txt" 2>&1
		log "kernel-report-scan exit $? (kernel-report-scan.txt)"
	fi
fi
log "ALL DONE"
