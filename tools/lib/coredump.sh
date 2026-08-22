# coredump.sh — the seam between bt-crash and the cores systemd retained.
#
#   source "$LIBDIR/coredump.sh"
#   bt_coredump_available          || echo "no core store here"
#   bt_coredumpctl list --no-pager
#   bt_coredumpctl info 313564 --no-pager
#
# In normal use `bt_coredumpctl` IS `coredumpctl`, argument for argument. When
# BT_COREDUMP_FIXTURE names a directory, the query is answered from a file in
# that directory instead.
#
# WHY THIS EXISTS. Same reason as journal.sh, one layer over: bt-crash is the
# tool this project reaches for first when the operator says Bluetooth is
# broken, because it is what separates EX-032 (BlueZ crashed, adapter still
# powered, discovery permanently dead) from BT-1 (the controller wedged). Those
# two look identical from the outside and are answered by completely different
# work. A tool that decides that cannot be left untested — and it could not be
# tested, because half its answer came from `coredumpctl` on the host.
#
# THIS IS A SMALL SEAM FOR ONE CALLER, DELIBERATELY. journal.sh was written
# against 109 call sites in 27 files; this one has four in one file. It is a
# file rather than four inline `${BT_COREDUMPCTL:-coredumpctl}` expansions for
# the same reason journal.sh is: the availability probe has to move with the
# calls. A tool that redirected its `coredumpctl` invocations but still asked
# `command -v coredumpctl` would refuse to run over a fixture on any host
# without systemd-coredump — which is every CI container this suite runs in,
# and is exactly the defect bt_journal_available was added to fix.
#
# FIXTURE LAYOUT. Files are chosen from the verb, so one directory answers
# every question bt-crash asks:
#
#   <dir>/list.txt          `coredumpctl list`
#   <dir>/info-<pid>.txt    `coredumpctl info <pid>`
#   <dir>/info.txt          any `info` with no matching per-pid file
#
# `list.txt` MUST CARRY THE HEADER ROW. `coredumpctl list` prints a `TIME PID
# UID GID SIG COREFILE EXE SIZE` header and every caller strips it with
# `tail -n +2`; a fixture written without one therefore loses its FIRST CORE
# silently, and a test over it passes while asserting one row too few. This is
# not hypothetical — the provenance fixture shipped without `--list-boots`'s
# header row and every fixture-driven test passed while the real tool crashed
# on real output (see journal-contract's header). Same shape, written down
# before it happens rather than after.
#
# A MISSING FIXTURE FILE IS "NO CORES", AND THAT MEANS EXIT 1 HERE. journal.sh
# makes a missing file an empty journal at exit 0 because that is what a real
# journal does when asked for a unit that never logged. The same rule — be the
# honest analogue — gives the opposite answer for this tool: `coredumpctl list`
# with nothing retained prints `No coredumps found.` to stderr and exits 1. A
# fixture that answered 0 would let a caller adopt `if bt_coredumpctl list;`
# and pass every test on the way to failing on the machine, in the direction
# that reports a crash store as empty. So the status is faithful, and the
# divergence from journal.sh is the rule being applied, not an exception to it.
#
# This file is SOURCED, so it must not set shell options, define traps, or run
# anything at load time — its callers set their own `set -uo pipefail` and
# would inherit whatever it changed.

# "Is a core store reachable at all?" belongs to the seam, for the reason given
# above: the seam decides WHERE cores come from, so it is the only thing that
# can say whether there are any to come from.
bt_coredump_available() {
    [[ -n "${BT_COREDUMP_FIXTURE:-}" ]] && return 0
    command -v coredumpctl >/dev/null 2>&1
}

bt_coredumpctl() {
    if [[ -z "${BT_COREDUMP_FIXTURE:-}" ]]; then
        coredumpctl "$@"
        return $?
    fi

    local dir="$BT_COREDUMP_FIXTURE" verb="" arg="" a
    # Only the two words that choose a FILE are read. Everything else —
    # --no-pager, -1, --since — is formatting or narrowing that a fixture
    # answers by simply being the text it is, the same contract bt_journal
    # keeps with its own selectors.
    for a in "$@"; do
        case "$a" in
            -*) ;;
            *)  if   [[ -z "$verb" ]]; then verb="$a"
                elif [[ -z "$arg"  ]]; then arg="$a"
                fi ;;
        esac
    done

    local cand=()
    case "$verb" in
        info|debug|dump) [[ -n "$arg" ]] && cand+=("$dir/info-$arg.txt")
                         cand+=("$dir/info.txt") ;;
        *)               cand+=("$dir/${verb:-list}.txt") ;;
    esac
    for a in "${cand[@]}"; do
        [[ -r "$a" ]] && { cat "$a"; return 0; }
    done

    echo "No coredumps found." >&2
    return 1
}
