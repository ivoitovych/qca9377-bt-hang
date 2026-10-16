#!/bin/bash
# ci-local.sh — the BlueZ CI bot's checks, run locally TWICE: on the base tree
# and on base plus the patches, so that every finding is classified as
#
#   PASS          nothing reported on either side
#   NEW           reported only with the patches applied   (ours; exit 1)
#   PRE-EXISTING  reported on both sides                    (upstream's)
#   FIXED         reported only on the base                 (the patches remove it)
#
# A lone run repeats the bot's noise; the base-vs-patched difference is what
# tells our findings from theirs. The 2026-10-10 bot run reported a smatch
# warning at emulator/btdev.c:479 on two of our series; it was upstream code and
# this script shows that as PRE-EXISTING (results/ci-local-2026-10-10.md).
#
#   scripts/ci-local.sh [options] <patch.mbox>...            BlueZ (user space)
#   scripts/ci-local.sh --kernel [options] <patch.mbox>...   kernel (bluetooth-next)
#
# The checks and their recipes are the bot's own, read from bluez/action-ci
# (cache/action-ci, see results/ci-local-2026-10-10.md §T1 for the pinned
# commit): pre-ci_am (git am of the series), CheckPatch (checkpatch.pl on the
# mbox, run inside the tree so its .checkpatch.conf applies), GitLint (the
# bot's own gitlint file, NOT BlueZ's .gitlint: title limit 80, Fixes:/Link:/URL
# body lines ignored; message = patchwork-style name + body), BuildEll,
# BluezMake (./bootstrap-configure; make), bluezmakeextell (--enable-external-ell
# --disable-lsan --disable-asan --disable-ubsan), CheckSmatch (--disable-asan
# --disable-lsan --disable-ubsan; make CHECK="smatch --full-path" CC=cgcc; the
# bot posts every smatch line on the files the series touches), ScanBuild
# (scan-build make, base vs patched like the bot), IncrementalBuild (git am and
# make after each patch), TestFunctional (test/test-functional, behind
# --functional: it boots VMs; without /dev/kvm qemu falls back to TCG and is
# slow). Kernel space: pre-ci_am against bluetooth-next master or, for an
# [x.y.y] stable backport, against the newest tag of that stable line (the
# bluetooth-next result is then reported as expected for a backport, not as a
# failure), CheckPatch (scripts/checkpatch.pl --ignore UNKNOWN_COMMIT_ID),
# VerifyFixes, VerifySignedoff, GitLint (+contrib-body-requires-signed-off-by),
# SubjectPrefix; with --build also BuildKernel, CheckAllWarning (W=1) and
# CheckSparse (C=1) on net/bluetooth/ and drivers/bluetooth/ with BlueZ's
# doc/ci.config.
#
# Options
#   --tree DIR         source tree (default cache/bluez; --kernel: cache/bluetooth-next-full)
#   --base REF         base ref (default origin/master); --fetch runs git fetch origin first
#   --ell DIR          ELL tree (default cache/ell; BlueZ wants it at ../ell of the source)
#   --smatch DIR       smatch build directory (default cache/smatch)
#   --checkpatch FILE  checkpatch.pl (default cache/checkpatch/checkpatch.pl; --kernel: the tree's)
#   --gitlint-config F gitlint config (default cache/action-ci/gitlint, the bot's)
#   --checks LIST      comma-separated subset of the check names above (lower case)
#   --functional       add TestFunctional (needs --kernel-image, qemu, the harness venv)
#   --kernel-image F   bzImage for TestFunctional
#   --functional-k EXP pytest -k expression for TestFunctional (default: the whole suite)
#   --build            kernel space: add BuildKernel, CheckAllWarning, CheckSparse
#   --stable-full      kernel space: fetch a stable tag with its history (VerifyFixes
#                      needs it; default --depth 1, which is enough for the apply check)
#   --bluez DIR        kernel space: BlueZ tree for doc/ci.config (default cache/bluez)
#   --jobs N           make -j (default: nproc)
#   --label NAME       name of this run (default: first patch's stem)
#   --out DIR          output directory (default tmp/ci-local/<UTC stamp>-<label>)
#   --no-reuse-base    recompute the base side even if tmp/ci-local/base-cache has it
#   --keep-work        keep the git worktree and build products under <out>/work
#
# Output: <out>/summary.txt (one line per check), <out>/<check>.{base,patched}.*
# logs, <out>/run.log. The base side is cached per base commit under
# tmp/ci-local/base-cache so a second series on the same master reuses it.
# Exit status: 0 = no NEW finding, 1 = a NEW finding, 2 = could not run.
#
# Everything the bot does that needs its tokens (patchwork posts, GitHub PRs,
# e-mail) is left out; nothing here talks to anything but the local trees.
set -uo pipefail
export LC_ALL=C

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SPACE=user
TREE=""
BASE=origin/master
FETCH=0
ELL="$REPO/cache/ell"
SMATCH="$REPO/cache/smatch"
CHECKPATCH=""
GITLINT_CFG="$REPO/cache/action-ci/gitlint"
GITLINT="$REPO/cache/gitlint-venv/bin/gitlint"
CHECKS=""
FUNCTIONAL=0
KERNEL_IMAGE=""
FUNCTIONAL_K=""
BUILD=0
STABLE_FULL=0
BLUEZ="$REPO/cache/bluez"
JOBS="$(nproc)"
LABEL=""
OUT=""
REUSE_BASE=1
KEEP_WORK=0
HARNESS_VENV="$REPO/cache/bluezenv-venv"
STABLE_URL="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"

usage() { sed -n '2,70p' "$0"; }

PATCHES=()
while (( $# )); do
	case "$1" in
	--kernel) SPACE=kernel ;;
	--tree) TREE="$2"; shift ;;
	--base) BASE="$2"; shift ;;
	--fetch) FETCH=1 ;;
	--ell) ELL="$2"; shift ;;
	--smatch) SMATCH="$2"; shift ;;
	--checkpatch) CHECKPATCH="$2"; shift ;;
	--gitlint-config) GITLINT_CFG="$2"; shift ;;
	--checks) CHECKS="$2"; shift ;;
	--functional) FUNCTIONAL=1 ;;
	--kernel-image) KERNEL_IMAGE="$2"; shift ;;
	--functional-k) FUNCTIONAL_K="$2"; shift ;;
	--build) BUILD=1 ;;
	--stable-full) STABLE_FULL=1 ;;
	--bluez) BLUEZ="$2"; shift ;;
	--jobs) JOBS="$2"; shift ;;
	--label) LABEL="$2"; shift ;;
	--out) OUT="$2"; shift ;;
	--no-reuse-base) REUSE_BASE=0 ;;
	--keep-work) KEEP_WORK=1 ;;
	-h|--help) usage; exit 0 ;;
	-*) echo "ci-local: unknown option $1" >&2; exit 2 ;;
	*) PATCHES+=("$(readlink -f "$1")") ;;
	esac
	shift
done
(( ${#PATCHES[@]} )) || { echo "ci-local: no patches given (see --help)" >&2; exit 2; }
for p in "${PATCHES[@]}"; do
	[[ -r "$p" ]] || { echo "ci-local: cannot read $p" >&2; exit 2; }
done

if [[ -z "$TREE" ]]; then
	[[ "$SPACE" == kernel ]] && TREE="$REPO/cache/bluetooth-next-full" || TREE="$REPO/cache/bluez"
fi
TREE="$(readlink -f "$TREE")"
[[ -d "$TREE/.git" || -f "$TREE/.git" ]] || { echo "ci-local: $TREE is not a git tree" >&2; exit 2; }
if [[ -z "$CHECKPATCH" ]]; then
	[[ "$SPACE" == kernel ]] && CHECKPATCH="$TREE/scripts/checkpatch.pl" || CHECKPATCH="$REPO/cache/checkpatch/checkpatch.pl"
fi
if [[ -z "$CHECKS" ]]; then
	if [[ "$SPACE" == kernel ]]; then
		CHECKS="am,checkpatch,verifyfixes,verifysignedoff,gitlint,subjectprefix"
		(( BUILD )) && CHECKS="$CHECKS,buildkernel,allwarning,sparse"
	else
		CHECKS="am,checkpatch,gitlint,buildell,make,makeextell,smatch,incremental,scanbuild"
		(( FUNCTIONAL )) && CHECKS="$CHECKS,functional"
	fi
fi
[[ -z "$LABEL" ]] && LABEL="$(basename "${PATCHES[0]}" .patch | cut -c1-40)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
[[ -z "$OUT" ]] && OUT="$REPO/tmp/ci-local/$STAMP-$LABEL"
mkdir -p "$OUT" || exit 2
OUT="$(readlink -f "$OUT")"
CACHE="$REPO/tmp/ci-local/base-cache"
mkdir -p "$CACHE"
WORK="$OUT/work"
mkdir -p "$WORK"
RUNLOG="$OUT/run.log"
SUMMARY="$OUT/summary.txt"
: > "$SUMMARY"

log() { printf '%s %s\n' "$(date -u +%H:%M:%S)" "$*" | tee -a "$RUNLOG"; }
want() { [[ ",$CHECKS," == *",$1,"* ]]; }

# run_to <stdout-file> <stderr-file> <cwd> <cmd...>  — prints the exit status
run_to() {
	local o="$1" e="$2" d="$3"; shift 3
	log "  \$ (cd ${d#"$WORK"/} && $*)"
	( cd "$d" && "$@" ) >"$o" 2>"$e"
	local rc=$?
	echo "exit status $rc" >>"$e"
	return $rc
}

# verdict <check> <verdict> <text...> — one summary line, details below it
verdict() {
	local check="$1" v="$2"; shift 2
	printf '%-18s %-13s %s\n' "$check" "$v" "$*" | tee -a "$SUMMARY"
}
detail() { sed 's/^/    /' | tee -a "$SUMMARY"; }

# classify <base-findings> <patched-findings> <report-file>
# Finding lines are "path:line:col: kind: message". Line and column numbers are
# dropped for the comparison (a patch that inserts lines above an old warning
# moves it; that is not a new warning) and the work directory prefix is
# removed. Prints NEW:/FIXED:/PRE-EXISTING: lines; returns 1 for NEW, 3 for
# FIXED only, 4 for PRE-EXISTING only, 0 for nothing.
classify() {
	python3 -I - "$1" "$2" "$WORK/" <<'PY'
import re, sys, collections
base, patched, prefix = sys.argv[1], sys.argv[2], sys.argv[3]
def norm(line):
    line = line.replace(prefix, "")
    line = re.sub(r'^(src|kernel|stable)/', '', line)
    return re.sub(r'^([^:\s]+):\d+(:\d+)?:', r'\1:L:C:', line.strip())
def load(f):
    c = collections.Counter(); raws = collections.defaultdict(list)
    for l in open(f, errors="replace"):
        l = l.rstrip("\n")
        if not l.strip():
            continue
        k = norm(l); c[k] += 1; raws[k].append(l.replace(prefix, ""))
    return c, raws
b, bf = load(base); p, pf = load(patched)
def show(raws_mine, raws_other, k):
    # the occurrence the other side lacks, by its exact text (line numbers
    # included), so a message repeated at a new place names the new place
    only = [r for r in raws_mine.get(k, []) if r not in raws_other.get(k, [])]
    return (only or raws_mine.get(k) or [k])[0]
rc = 0; new = fixed = pre = 0
for k in sorted(set(b) | set(p)):
    nb, np_ = b.get(k, 0), p.get(k, 0)
    if np_ > nb:
        print(f"NEW: {show(pf, bf, k)}" + (f"  (x{np_ - nb})" if np_ - nb > 1 else "")); new += 1
    if nb > np_:
        print(f"FIXED: {show(bf, pf, k)}" + (f"  (x{nb - np_})" if nb - np_ > 1 else "")); fixed += 1
    if min(nb, np_) > 0:
        print(f"PRE-EXISTING: {pf[k][0]}" + (f"  (x{min(nb, np_)})" if min(nb, np_) > 1 else "")); pre += 1
print(f"# counts: new={new} fixed={fixed} pre-existing={pre}")
sys.exit(1 if new else 3 if fixed else 4 if pre else 0)
PY
}

# verdict_from_classes <check> <base-findings> <patched-findings>
verdict_from_classes() {
	local check="$1" rep="$OUT/$check.classified.txt"
	classify "$2" "$3" >"$rep"
	local rc=$?
	case $rc in
	0) verdict "$check" PASS "no finding on either side" ;;
	1) verdict "$check" NEW "$(grep -c '^NEW:' "$rep") new, $(grep -c '^FIXED:' "$rep") fixed, $(grep -c '^PRE-EXISTING:' "$rep") pre-existing"; NEWS=$((NEWS + 1)) ;;
	3) verdict "$check" FIXED "$(grep -c '^FIXED:' "$rep") fixed, $(grep -c '^PRE-EXISTING:' "$rep") pre-existing" ;;
	4) verdict "$check" PRE-EXISTING "$(grep -c '^PRE-EXISTING:' "$rep") pre-existing, none new" ;;
	esac
	grep -v '^# counts' "$rep" | detail
}

# Finding extraction: compiler/analyzer diagnostics "file:line[:col]: kind: ..."
findings() { grep -E '^[^ :]+\.(c|h|y|l):[0-9]+(:[0-9]+)?: (warning|error|note: in included file|fatal error)' "$1" | grep -v '^exit status' > "$2" || true; }

# patchwork-style name of a patch: "[PATCH BlueZ 1/3] x" -> "[BlueZ,1/3] x"
pw_name() {
	awk '
		/^Subject: / { s = substr($0, 10); folded = 1; next }
		folded && /^[ \t]/ { sub(/^[ \t]+/, " "); s = s $0; next }
		folded { print s; exit }' "$1" | python3 -I -c '
import re, sys
s = sys.stdin.read().strip()
m = re.match(r"^\[([^\]]*)\]\s*(.*)$", s)
if not m:
    print(s); sys.exit()
tags = [t for t in re.split(r"[\s,]+", m.group(1)) if t and t.upper() != "PATCH"]
print(("[" + ",".join(tags) + "] " if tags else "") + m.group(2))'
}

# message body as patchwork stores it: everything after the mail headers and
# before the diff (the "---" separator and diffstat included)
pw_body() {
	awk '
		/^diff --git / { exit }
		hdr && /^$/ { hdr = 0; next }
		hdr { next }
		{ print }' hdr=1 "$1"
}

subject_of() { pw_name "$1"; }

NEWS=0
SKIPPED=()

# git am records a committer. The scratch worktrees have no identity of their
# own, and the environment's global one must not appear even there, so every
# am below commits as the project checkout's configured identity (the bot's
# committer is its GitHub actor; VerifySignedoff looks at the committer, so a
# difference there is this reproduction's, see the results file).
CI_NAME="$(git -C "$REPO" config user.name 2>/dev/null || true)"
CI_EMAIL="$(git -C "$REPO" config user.email 2>/dev/null || true)"
[[ -n "$CI_NAME" && -n "$CI_EMAIL" ]] || { echo "ci-local: the project checkout has no user.name/user.email configured" >&2; exit 2; }
git_am() { git -C "$1" -c user.name="$CI_NAME" -c user.email="$CI_EMAIL" -c commit.gpgsign=false am "${@:2}"; }

################################################################################
log "ci-local: space=$SPACE tree=$TREE base=$BASE checks=$CHECKS jobs=$JOBS"
log "ci-local: out=$OUT"
for p in "${PATCHES[@]}"; do log "  patch: ${p#"$REPO"/} :: $(subject_of "$p")"; done
cp "${PATCHES[@]}" "$OUT/" 2>/dev/null

if (( FETCH )); then
	git -C "$TREE" fetch --quiet origin || { echo "ci-local: git fetch failed" >&2; exit 2; }
fi
BASE_SHA="$(git -C "$TREE" rev-parse --verify "$BASE^{commit}" 2>/dev/null)" || { echo "ci-local: no such base $BASE in $TREE" >&2; exit 2; }
log "ci-local: base commit $BASE_SHA $(git -C "$TREE" log -1 --format='%cs %s' "$BASE_SHA")"
echo "base $BASE_SHA $(git -C "$TREE" log -1 --format='%cs %s' "$BASE_SHA")" >>"$SUMMARY"
echo "tree $TREE" >>"$SUMMARY"
for p in "${PATCHES[@]}"; do echo "patch $(basename "$p") :: $(subject_of "$p")" >>"$SUMMARY"; done
echo >>"$SUMMARY"

################################################################################
# Kernel space: which tree is the target? A "[x.y.y]" (or "x.y.y" inside the
# tag) subject is a stable backport; the target is then the newest tag of that
# line and bluetooth-next is only consulted to show the expected failure.
TARGET_DESC="$BASE"
TARGET_SHA="$BASE_SHA"
STABLE_LINE=""
UPSTREAM_COMMIT=""
if [[ "$SPACE" == kernel ]]; then
	STABLE_LINE="$(subject_of "${PATCHES[0]}" | grep -oE '^\[[^]]*\b[0-9]+\.[0-9]+\.y\b' | grep -oE '[0-9]+\.[0-9]+\.y' | head -1)"
	UPSTREAM_COMMIT="$(grep -ohE '^\[ Upstream commit [0-9a-f]{12,40} \]|^commit [0-9a-f]{12,40} upstream\.?$|^\[ upstream commit [0-9a-f]{12,40} \]' "${PATCHES[0]}" | grep -oE '[0-9a-f]{12,40}' | head -1)"
	if [[ -n "$STABLE_LINE" ]]; then
		log "ci-local: stable backport for $STABLE_LINE detected in the subject"
		if ! git -C "$TREE" remote get-url stable >/dev/null 2>&1; then
			git -C "$TREE" remote add stable "$STABLE_URL"
		fi
		MAJMIN="${STABLE_LINE%.y}"
		TAG="$(git -C "$TREE" ls-remote --tags --refs stable "refs/tags/v$MAJMIN.*" 2>>"$RUNLOG" | awk '{print $2}' | sed 's#refs/tags/##' | grep -vE 'rc' | sort -V | tail -1)"
		if [[ -z "$TAG" ]]; then
			log "ci-local: cannot list stable tags for v$MAJMIN.* (network?)"
			verdict am "NOT RUN" "stable tags for v$MAJMIN.* could not be listed"; SKIPPED+=(am)
		else
			log "ci-local: newest $STABLE_LINE tag is $TAG"
			# A tag already here from an earlier --depth 1 run is deepened when
			# --stable-full asks for its history.
			if (( STABLE_FULL )) && git -C "$TREE" rev-parse --verify "refs/tags/$TAG^{commit}" >/dev/null 2>&1 && grep -qx "$(git -C "$TREE" rev-parse "refs/tags/$TAG^{commit}")" "$(git -C "$TREE" rev-parse --absolute-git-dir)/shallow" 2>/dev/null; then
				log "ci-local: $TAG is here without history; fetching its history from stable (--unshallow)"
				git -C "$TREE" fetch --quiet --no-tags --unshallow stable "refs/tags/$TAG:refs/tags/$TAG" 2>>"$RUNLOG" || log "ci-local: deepening $TAG failed; VerifyFixes stays NOT RUN"
			fi
			if ! git -C "$TREE" rev-parse --verify "refs/tags/$TAG^{commit}" >/dev/null 2>&1; then
				# kernel.org ignores partial-clone filters ("filtering not
				# recognized by server"), so the choice is the tag's tree alone
				# (--depth 1, enough for the apply check) or its whole history
				# (--stable-full, needed for VerifyFixes ancestry; about 1 GB).
				if (( STABLE_FULL )); then
					log "ci-local: fetching $TAG from stable with its history"
					git -C "$TREE" fetch --quiet --no-tags stable "refs/tags/$TAG:refs/tags/$TAG" 2>>"$RUNLOG" || { verdict am "NOT RUN" "fetch of $TAG failed"; SKIPPED+=(am); TAG=""; }
				else
					log "ci-local: fetching $TAG from stable with --depth 1 (tree only; --stable-full for history)"
					git -C "$TREE" fetch --quiet --no-tags --depth 1 stable "refs/tags/$TAG:refs/tags/$TAG" 2>>"$RUNLOG" || { verdict am "NOT RUN" "fetch of $TAG failed"; SKIPPED+=(am); TAG=""; }
				fi
			fi
			if [[ -n "$TAG" ]]; then
				TARGET_DESC="$TAG"
				TARGET_SHA="$(git -C "$TREE" rev-parse --verify "refs/tags/$TAG^{commit}")"
			fi
		fi
		echo "target $TARGET_DESC $TARGET_SHA (stable line $STABLE_LINE)" >>"$SUMMARY"
		[[ -n "$UPSTREAM_COMMIT" ]] && echo "upstream commit named by the backport: $UPSTREAM_COMMIT" >>"$SUMMARY"
	fi
fi

################################################################################
# Work tree at the target. ELL is wanted at ../ell by BlueZ's configure.
if [[ "$SPACE" == user ]]; then
	SRC="$WORK/src"
	git -C "$TREE" worktree add --quiet --detach "$SRC" "$TARGET_SHA" 2>>"$RUNLOG" || { echo "ci-local: worktree add failed (see $RUNLOG)" >&2; exit 2; }
	ln -sfn "$ELL" "$WORK/ell"
else
	SRC="$WORK/kernel"
	if want verifyfixes || want verifysignedoff || want buildkernel || want allwarning || want sparse || want incremental; then
		log "ci-local: checking out $TARGET_DESC into a worktree (a partial clone fetches the blobs now)"
		git -C "$TREE" worktree add --quiet --detach "$SRC" "$TARGET_SHA" 2>>"$RUNLOG" || { echo "ci-local: worktree add failed (see $RUNLOG)" >&2; exit 2; }
	fi
fi
cleanup() {
	if (( ! KEEP_WORK )); then
		[[ -d "$SRC" ]] && git -C "$TREE" worktree remove --force "$SRC" 2>/dev/null
		rm -rf "$WORK"
	fi
}
trap cleanup EXIT

################################################################################
# pre-ci_am — git am of the series onto the target, in order
AM_OK=1
if want am; then
	if [[ -d "$SRC" ]]; then
		if run_to "$OUT/am.out" "$OUT/am.err" "$SRC" git -c user.name="$CI_NAME" -c user.email="$CI_EMAIL" -c commit.gpgsign=false am "${PATCHES[@]}"; then
			verdict am PASS "all ${#PATCHES[@]} patch(es) apply to $TARGET_DESC with git am"
		else
			AM_OK=0
			git -C "$SRC" am --abort 2>/dev/null
			verdict am NEW "git am failed on $TARGET_DESC"; NEWS=$((NEWS + 1))
			grep -v '^exit status' "$OUT/am.err" | detail
		fi
		git -C "$SRC" reset --quiet --hard "$TARGET_SHA"
	else
		# no worktree: apply to a scratch index, in series order
		idx="$OUT/am.index"; rm -f "$idx"
		GIT_INDEX_FILE="$idx" git -C "$TREE" read-tree "$TARGET_SHA"
		ok=1
		for p in "${PATCHES[@]}"; do
			if ! GIT_INDEX_FILE="$idx" git -C "$TREE" apply --cached "$p" 2>>"$OUT/am.err"; then ok=0; break; fi
		done
		if (( ok )); then verdict am PASS "all ${#PATCHES[@]} patch(es) apply to $TARGET_DESC (git apply --check, series order)"
		else AM_OK=0; verdict am NEW "the series does not apply to $TARGET_DESC"; NEWS=$((NEWS + 1)); detail <"$OUT/am.err"; fi
	fi
	if [[ "$SPACE" == kernel && -n "$STABLE_LINE" ]]; then
		# what the bot does: the same series onto bluetooth-next master
		idx="$OUT/am-bluetooth-next.index"; rm -f "$idx"
		GIT_INDEX_FILE="$idx" git -C "$TREE" read-tree "$BASE_SHA"
		if GIT_INDEX_FILE="$idx" git -C "$TREE" apply --cached "${PATCHES[@]}" 2>"$OUT/am-bluetooth-next.err"; then
			verdict am-bluetooth-next PASS "the backport also applies to $BASE ($BASE_SHA) — unusual for a backport, check that the fix is really missing there"
		else
			note="does not apply to $BASE — expected for a backport"
			if [[ -n "$UPSTREAM_COMMIT" ]]; then
				if git -C "$TREE" merge-base --is-ancestor "$UPSTREAM_COMMIT" "$BASE_SHA" 2>/dev/null; then
					note="$note: upstream commit $UPSTREAM_COMMIT is in $BASE already"
				elif git -C "$TREE" cat-file -e "$UPSTREAM_COMMIT^{commit}" 2>/dev/null; then
					note="$note; upstream commit $UPSTREAM_COMMIT exists but is NOT an ancestor of $BASE"
				else
					note="$note; upstream commit $UPSTREAM_COMMIT is not in this clone (history too shallow?)"
				fi
			fi
			verdict am-bluetooth-next EXPECTED "$note"
			detail <"$OUT/am-bluetooth-next.err"
		fi
	fi
fi

################################################################################
# CheckPatch — the mbox through checkpatch.pl, inside the tree
if want checkpatch; then
	if [[ ! -f "$CHECKPATCH" ]]; then
		verdict checkpatch "NOT RUN" "no checkpatch.pl at $CHECKPATCH"; SKIPPED+=(checkpatch)
	else
		cpdir="$TREE"; [[ -d "$SRC" ]] && cpdir="$SRC"
		[[ "$SPACE" == kernel && ! -f "$cpdir/scripts/checkpatch.pl" ]] && cpdir="$TREE"
		worst=PASS; : >"$OUT/checkpatch.txt"
		for p in "${PATCHES[@]}"; do
			args=()
			[[ "$SPACE" == kernel ]] && args=(--ignore UNKNOWN_COMMIT_ID)
			( cd "$cpdir" && perl "$CHECKPATCH" "${args[@]}" "$p" ) >"$OUT/checkpatch.$(basename "$p").out" 2>&1
			out="$OUT/checkpatch.$(basename "$p").out"
			echo "== $(basename "$p")" >>"$OUT/checkpatch.txt"
			cat "$out" >>"$OUT/checkpatch.txt"
			if grep -q '^ERROR:' "$out"; then worst=NEW
			elif grep -q '^WARNING:' "$out" && [[ $worst != NEW ]]; then worst="NEW(warning)"; fi
		done
		if [[ $worst == PASS ]]; then verdict checkpatch PASS "no ERROR or WARNING from checkpatch (version $(perl "$CHECKPATCH" --version 2>/dev/null | awk '/Version/{print $2}'))"
		else
			verdict checkpatch "$worst" "checkpatch reports on the patches (the bot: ERROR = fail, WARNING = warning)"; NEWS=$((NEWS + 1))
			grep -E '^(==|ERROR:|WARNING:|CHECK:|#|total:)' "$OUT/checkpatch.txt" | detail
		fi
	fi
fi

################################################################################
# GitLint — bot config, patchwork-style message
if want gitlint; then
	if [[ ! -x "$GITLINT" ]]; then
		verdict gitlint "NOT RUN" "no gitlint at $GITLINT (scripts/gitlint-check.sh creates the venv)"; SKIPPED+=(gitlint)
	elif [[ ! -f "$GITLINT_CFG" ]]; then
		verdict gitlint "NOT RUN" "no gitlint config at $GITLINT_CFG"; SKIPPED+=(gitlint)
	else
		bad=0; : >"$OUT/gitlint.txt"
		for p in "${PATCHES[@]}"; do
			msg="$OUT/gitlint.$(basename "$p").msg"
			{ pw_name "$p"; echo; pw_body "$p"; } >"$msg"
			args=(-C "$GITLINT_CFG" --msg-filename "$msg")
			[[ "$SPACE" == kernel ]] && args+=(--contrib contrib-body-requires-signed-off-by)
			echo "== $(basename "$p")" >>"$OUT/gitlint.txt"
			if ( cd "$TREE" && "$GITLINT" "${args[@]}" ) >>"$OUT/gitlint.txt" 2>&1; then echo "   PASS" >>"$OUT/gitlint.txt"; else bad=$((bad + 1)); fi
		done
		if (( bad )); then verdict gitlint NEW "$bad patch(es) with gitlint violations ($("$GITLINT" --version 2>/dev/null))"; NEWS=$((NEWS + 1)); detail <"$OUT/gitlint.txt"
		else verdict gitlint PASS "no violations with the bot's config ($("$GITLINT" --version 2>/dev/null))"; fi
	fi
fi

################################################################################
# SubjectPrefix (kernel)
if want subjectprefix; then
	bad=0
	for p in "${PATCHES[@]}"; do
		subj="$(subject_of "$p")"
		# not a pipeline into grep -q: under pipefail that would invert
		grep -q 'Bluetooth: ' <<<"$subj" || { bad=$((bad + 1)); echo "no \"Bluetooth: \" in: $subj" >>"$OUT/subjectprefix.txt"; }
	done
	if (( bad )); then verdict subjectprefix NEW "$bad subject(s) without the \"Bluetooth: \" prefix"; NEWS=$((NEWS + 1)); detail <"$OUT/subjectprefix.txt"
	else verdict subjectprefix PASS "every subject carries \"Bluetooth: \""; fi
fi

################################################################################
# BuildEll — once; not a property of the patches
if want buildell; then
	if [[ ! -x "$ELL/bootstrap-configure" ]]; then
		verdict buildell "NOT RUN" "no ELL tree at $ELL"; SKIPPED+=(buildell)
	else
		if run_to "$OUT/buildell.out" "$OUT/buildell.err" "$ELL" ./bootstrap-configure && run_to "$OUT/buildell.make.out" "$OUT/buildell.make.err" "$ELL" make -j"$JOBS" && run_to "$OUT/buildell.install.out" "$OUT/buildell.install.err" "$ELL" make install; then
			verdict buildell PASS "ELL $(git -C "$ELL" log -1 --format=%h) configured, built and installed"
		else
			verdict buildell PRE-EXISTING "ELL does not build here (independent of the patches); see buildell.*.err"
			tail -5 "$OUT/buildell.make.err" 2>/dev/null | detail
		fi
	fi
fi

################################################################################
# Two-sided build checks. side_build <check> <side> <configure args...> -- <make args...>
# Produces <out>/<check>.<side>.findings and returns the build status.
bluez_build() {
	local check="$1" side="$2"; shift 2
	local cfg=() mk=()
	while (( $# )) && [[ "$1" != "--" ]]; do cfg+=("$1"); shift; done
	shift || true
	mk=("$@")
	local o="$OUT/$check.$side"
	run_to "$o.configure.out" "$o.configure.err" "$SRC" ./bootstrap-configure "${cfg[@]}" || { echo "configure failed" >"$o.findings"; return 1; }
	local tool=make
	[[ "$check" == scanbuild ]] && { tool=scan-build; command -v scan-build >/dev/null || tool=scan-build-18; }
	if [[ "$check" == scanbuild ]]; then
		run_to "$o.make.out" "$o.make.err" "$SRC" "$tool" -o "$o.scan-build-reports" make -j"$JOBS" "${mk[@]}"
	else
		run_to "$o.make.out" "$o.make.err" "$SRC" make -j"$JOBS" "${mk[@]}"
	fi
	local rc=$?
	findings "$o.make.err" "$o.findings"
	# smatch prints its own lines on stderr with --full-path; keep them as the bot does (every line)
	if [[ "$check" == smatch ]]; then
		grep -E '^[^ :]+\.(c|h):[0-9]+(:[0-9]+)?: (warning|error|info|parse error)' "$o.make.err" | sed "s#^$SRC/##" > "$o.findings" || true
	fi
	if (( rc )); then
		{ echo "BUILD FAILED: make exit status $rc"; grep -E 'error:|Error [0-9]+' "$o.make.err" | head -20; } >>"$o.findings"
	fi
	return $rc
}

# base_side <check> <configure args...> -- <make args...>: run on the base or reuse the cache
base_side() {
	local check="$1"; shift
	local key="$SPACE-$BASE_SHA-$check-$(echo "$*" | md5sum | cut -c1-8)"
	local cached="$CACHE/$key.findings"
	if (( REUSE_BASE )) && [[ -f "$cached" ]]; then
		cp "$cached" "$OUT/$check.base.findings"
		cp "$CACHE/$key.rc" "$OUT/$check.base.rc" 2>/dev/null || echo 0 >"$OUT/$check.base.rc"
		log "  base side of $check reused from $cached ($(wc -l <"$cached") finding lines)"
		return
	fi
	git -C "$SRC" reset --quiet --hard "$TARGET_SHA"
	bluez_build "$check" base "$@"
	local rc=$?
	echo $rc >"$OUT/$check.base.rc"
	# Only a base side that built is worth reusing: a configure or build failure
	# on the base is usually this machine's missing package, fixed before the
	# next run, and a cached failure would then be compared against for ever.
	if (( rc == 0 )); then
		cp "$OUT/$check.base.findings" "$cached"
		cp "$OUT/$check.base.rc" "$CACHE/$key.rc"
		cp "$OUT/$check.base.make.err" "$CACHE/$key.make.err" 2>/dev/null
	else
		log "  base side of $check failed (rc=$rc); not cached"
	fi
}

two_sided() {
	local check="$1"; shift
	log "== $check: base side"
	base_side "$check" "$@"
	if (( ! AM_OK )); then verdict "$check" "NOT RUN" "patched side skipped: the series does not apply"; SKIPPED+=("$check"); return; fi
	log "== $check: patched side"
	git -C "$SRC" reset --quiet --hard "$TARGET_SHA"
	git_am "$SRC" --quiet "${PATCHES[@]}" >>"$RUNLOG" 2>&1 || { git -C "$SRC" am --abort; verdict "$check" "NOT RUN" "git am failed unexpectedly"; return; }
	bluez_build "$check" patched "$@"
	local prc=$?
	local brc; brc="$(cat "$OUT/$check.base.rc" 2>/dev/null || echo 0)"
	if (( prc )) && (( ! brc )); then
		verdict "$check" NEW "the build fails with the patches and succeeds on the base"; NEWS=$((NEWS + 1))
		detail <"$OUT/$check.patched.findings"
	elif (( prc )) && (( brc )); then
		verdict "$check" PRE-EXISTING "the build fails on both sides"
		detail <"$OUT/$check.patched.findings"
	elif (( ! prc )) && (( brc )); then
		verdict "$check" FIXED "the build fails on the base and succeeds with the patches"
	else
		verdict_from_classes "$check" "$OUT/$check.base.findings" "$OUT/$check.patched.findings"
	fi
	if [[ "$check" == smatch ]]; then
		# What the bot posts: every smatch line on a file the series touches
		# (new files excluded), from the patched build.
		touched="$(for p in "${PATCHES[@]}"; do grep -E '^--- [^/]' "$p" | grep -v dev/null | sed 's#^--- [^/]*/##'; done | sort -u)"
		: >"$OUT/smatch.bot-view.txt"
		for f in $touched; do grep -F "$f:" "$OUT/smatch.patched.findings" >>"$OUT/smatch.bot-view.txt" || true; done
		if [[ -s "$OUT/smatch.bot-view.txt" ]]; then
			echo "    the bot would post (every smatch line on the touched files):" | tee -a "$SUMMARY"
			detail <"$OUT/smatch.bot-view.txt"
		else
			echo "    the bot would post: CheckSmatch PASS (no smatch line on the touched files)" | tee -a "$SUMMARY"
		fi
	fi
}

if [[ "$SPACE" == user ]]; then
	if want make;       then two_sided make -- ; fi
	if want makeextell; then two_sided makeextell --enable-external-ell --disable-lsan --disable-asan --disable-ubsan -- ; fi
	if want smatch; then
		if [[ -x "$SMATCH/smatch" && -x "$SMATCH/cgcc" ]]; then
			two_sided smatch --disable-asan --disable-lsan --disable-ubsan -- "CHECK=$SMATCH/smatch --full-path" "CC=$SMATCH/cgcc"
		else verdict smatch "NOT RUN" "no smatch at $SMATCH"; SKIPPED+=(smatch); fi
	fi
	if want incremental; then
		if (( ! AM_OK )); then verdict incremental "NOT RUN" "the series does not apply"; SKIPPED+=(incremental)
		else
			log "== incremental"
			git -C "$SRC" reset --quiet --hard "$TARGET_SHA"
			if ! run_to "$OUT/incremental.configure.out" "$OUT/incremental.configure.err" "$SRC" ./bootstrap-configure; then
				verdict incremental PRE-EXISTING "bootstrap-configure fails on the base"
			else
				fail=""
				for p in "${PATCHES[@]}"; do
					git_am "$SRC" --quiet "$p" >>"$RUNLOG" 2>&1 || { fail="git am $(basename "$p")"; break; }
					run_to "$OUT/incremental.$(basename "$p").make.out" "$OUT/incremental.$(basename "$p").make.err" "$SRC" make -j"$JOBS" || { fail="make after $(basename "$p")"; break; }
				done
				if [[ -n "$fail" ]]; then verdict incremental NEW "$fail failed"; NEWS=$((NEWS + 1)); grep -E 'error' "$OUT"/incremental.*.make.err | head -20 | detail
				else verdict incremental PASS "git am + make succeeded after each of the ${#PATCHES[@]} patch(es)"; fi
			fi
		fi
	fi
	if want scanbuild; then
		if command -v scan-build >/dev/null || command -v scan-build-18 >/dev/null; then
			two_sided scanbuild --disable-asan --disable-lsan --disable-ubsan --
		else verdict scanbuild "NOT RUN" "no scan-build (clang-tools)"; SKIPPED+=(scanbuild); fi
	fi
	if want functional; then
		if [[ -z "$KERNEL_IMAGE" || ! -f "$KERNEL_IMAGE" ]]; then
			verdict functional "NOT RUN" "--kernel-image <bzImage> is required (the bot builds bluetooth-next with doc/tester.config)"; SKIPPED+=(functional)
		elif [[ ! -x "$HARNESS_VENV/bin/python" ]]; then
			verdict functional "NOT RUN" "no harness venv at $HARNESS_VENV (python3 -m venv --system-site-packages; pip install pytest-bluezenv==0.1.9)"; SKIPPED+=(functional)
		else
			[[ -c /dev/kvm ]] || log "  WARNING: no /dev/kvm; test-runner's accel=kvm:tcg falls back to software emulation (slow, timings differ from the bot's)"
			for side in base patched; do
				log "== functional: $side side"
				git -C "$SRC" reset --quiet --hard "$TARGET_SHA"
				[[ $side == patched ]] && { git_am "$SRC" --quiet "${PATCHES[@]}" >>"$RUNLOG" 2>&1 || { verdict functional "NOT RUN" "git am failed"; break; }; }
				o="$OUT/functional.$side"
				run_to "$o.configure.out" "$o.configure.err" "$SRC" ./bootstrap-configure --disable-lsan --enable-asan --enable-ubsan || { echo "configure failed" >"$o.findings"; continue; }
				run_to "$o.make.out" "$o.make.err" "$SRC" make -j"$JOBS" || { echo "build failed" >"$o.findings"; continue; }
				kargs=()
				[[ -n "$FUNCTIONAL_K" ]] && kargs=(-k "$FUNCTIONAL_K")
				PATH="$HARNESS_VENV/bin:$PATH" run_to "$o.pytest.out" "$o.pytest.err" "$SRC" test/test-functional -vv --junit-xml "$o.xml" -m "not tester" -ra --vm-timeout 60 --kernel "$KERNEL_IMAGE" "${kargs[@]}"
				python3 -I - "$o.xml" > "$o.findings" <<'PY' || true
import sys, xml.etree.ElementTree as ET
try:
    tree = ET.parse(sys.argv[1])
except Exception as e:
    print(f"functional: no junit result ({e})"); sys.exit(0)
for tc in tree.findall(".//testcase"):
    name = tc.attrib.get("classname", "") + "::" + tc.attrib["name"]
    for err in tc.findall(".//error") + tc.findall(".//failure"):
        msg = err.attrib.get("message", "").splitlines()[0] if err.attrib.get("message") else err.tag
        print(f"FAIL {name}: {msg[:160]}")
PY
			done
			if [[ -f "$OUT/functional.base.findings" && -f "$OUT/functional.patched.findings" ]]; then
				verdict_from_classes functional "$OUT/functional.base.findings" "$OUT/functional.patched.findings"
			fi
		fi
	fi
fi

################################################################################
# Kernel space
if [[ "$SPACE" == kernel ]]; then
	if want verifyfixes || want verifysignedoff; then
		if (( ! AM_OK )) || [[ ! -d "$SRC" ]]; then
			verdict verifyfixes "NOT RUN" "needs the series applied in a worktree"; verdict verifysignedoff "NOT RUN" "needs the series applied in a worktree"; SKIPPED+=(verifyfixes verifysignedoff)
		else
			git -C "$SRC" reset --quiet --hard "$TARGET_SHA"
			if git_am "$SRC" --quiet "${PATCHES[@]}" >>"$RUNLOG" 2>&1; then
				range="$TARGET_SHA..HEAD"
				for s in verifyfixes:verify_fixes.sh verifysignedoff:verify_signedoff.sh; do
					name="${s%%:*}"; script="$REPO/cache/action-ci/scripts/${s##*:}"
					want "$name" || continue
					if [[ ! -x "$script" ]]; then verdict "$name" "NOT RUN" "no $script (clone bluez/action-ci into cache/action-ci)"; SKIPPED+=("$name"); continue; fi
					# A tag fetched with --depth 1 has no parents here: every Fixes:
					# target then reads as "not an ancestor", which is the fetch
					# depth speaking, not the patch.
					if [[ "$name" == verifyfixes ]] && grep -qx "$TARGET_SHA" "$(git -C "$TREE" rev-parse --absolute-git-dir)/shallow" 2>/dev/null; then
						verdict "$name" "NOT RUN" "$TARGET_DESC was fetched with --depth 1; Fixes: ancestry cannot be checked (use --stable-full)"; SKIPPED+=("$name"); continue
					fi
					if run_to "$OUT/$name.out" "$OUT/$name.err" "$SRC" "$script" "$range"; then verdict "$name" PASS "$(basename "$script") $range: no complaint"
					else verdict "$name" NEW "$(basename "$script") complains (the bot posts this as a warning)"; NEWS=$((NEWS + 1)); cat "$OUT/$name.out" | detail; fi
				done
			else
				git -C "$SRC" am --abort 2>/dev/null
				verdict verifyfixes "NOT RUN" "git am onto $TARGET_DESC failed"; SKIPPED+=(verifyfixes verifysignedoff)
			fi
			git -C "$SRC" reset --quiet --hard "$TARGET_SHA"
		fi
	fi
	if want buildkernel || want allwarning || want sparse; then
		KCONFIG="$BLUEZ/doc/ci.config"
		if [[ ! -f "$KCONFIG" ]]; then
			verdict buildkernel "NOT RUN" "no $KCONFIG"; SKIPPED+=(buildkernel allwarning sparse)
		else
			kernel_build() {   # kernel_build <check> <side> <make extra args...>
				local check="$1" side="$2"; shift 2
				local o="$OUT/$check.$side"
				cp "$KCONFIG" "$SRC/.config"
				run_to "$o.olddefconfig.out" "$o.olddefconfig.err" "$SRC" make olddefconfig "$@" || { echo "olddefconfig failed" >"$o.findings"; return 1; }
				run_to "$o.make.out" "$o.make.err" "$SRC" make -j"$JOBS" "$@" net/bluetooth/ drivers/bluetooth/
				local rc=$?
				findings "$o.make.err" "$o.findings"
				(( rc )) && { echo "BUILD FAILED: make exit status $rc"; grep -E 'error:' "$o.make.err" | head -20; } >>"$o.findings"
				return $rc
			}
			for spec in "buildkernel:" "allwarning:W=1" "sparse:C=1"; do
				check="${spec%%:*}"; extra="${spec#*:}"
				want "$check" || continue
				if [[ "$check" == sparse ]] && ! command -v sparse >/dev/null; then verdict sparse "NOT RUN" "no sparse binary"; SKIPPED+=(sparse); continue; fi
				log "== $check: base side"
				git -C "$SRC" reset --quiet --hard "$TARGET_SHA"
				run_to "$OUT/$check.clean.out" "$OUT/$check.clean.err" "$SRC" make clean >/dev/null 2>&1
				kernel_build "$check" base $extra; brc=$?
				if (( ! AM_OK )); then verdict "$check" "NOT RUN" "the series does not apply"; SKIPPED+=("$check"); continue; fi
				log "== $check: patched side"
				git_am "$SRC" --quiet "${PATCHES[@]}" >>"$RUNLOG" 2>&1 || { verdict "$check" "NOT RUN" "git am failed"; continue; }
				kernel_build "$check" patched $extra; prc=$?
				if (( prc )) && (( ! brc )); then verdict "$check" NEW "the build fails with the patches and succeeds on the base"; NEWS=$((NEWS + 1)); detail <"$OUT/$check.patched.findings"
				elif (( prc )) && (( brc )); then verdict "$check" PRE-EXISTING "the build fails on both sides"; detail <"$OUT/$check.patched.findings"
				elif (( ! prc )) && (( brc )); then verdict "$check" FIXED "the build fails on the base and succeeds with the patches"
				else verdict_from_classes "$check" "$OUT/$check.base.findings" "$OUT/$check.patched.findings"; fi
				if [[ "$check" == sparse ]] && ! grep -q 'CHECK ' "$OUT/$check.patched.make.out" "$OUT/$check.patched.make.err" 2>/dev/null; then
					echo "    WARNING: no CHECK line in the build output — sparse was not run by this kernel (too old a sparse is skipped silently)" | tee -a "$SUMMARY"
				fi
				git -C "$SRC" reset --quiet --hard "$TARGET_SHA"
			done
		fi
	fi
fi

################################################################################
echo >>"$SUMMARY"
if (( NEWS )); then
	log "RESULT: $NEWS check(s) with a NEW finding — see $SUMMARY"
	echo "RESULT: NEW findings in $NEWS check(s)" >>"$SUMMARY"
	exit 1
fi
if (( ${#SKIPPED[@]} )); then
	log "RESULT: no NEW finding; not run: ${SKIPPED[*]}"
	echo "RESULT: no NEW finding; not run: ${SKIPPED[*]}" >>"$SUMMARY"
else
	log "RESULT: no NEW finding"
	echo "RESULT: no NEW finding" >>"$SUMMARY"
fi
exit 0
