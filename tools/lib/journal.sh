# journal.sh — the seam between the analysis tools and the host journal.
#
#   source "$LIBDIR/journal.sh"
#   bt_journal -k -b 0 --no-pager -o short-iso-precise
#
# In normal use `bt_journal` IS `journalctl`, argument for argument. When
# BT_JOURNAL_FIXTURE names a directory, the query is answered from a file in
# that directory instead, so a tool can be driven over a known journal without
# a journal — or a machine — being present.
#
# WHY THIS EXISTS.
#
# `devtools/coverage` measured that 41 of 43 tracked shell scripts execute no
# line under test. The cause is not missing effort; it is that these tools shell
# out to `journalctl` directly, at 109 call sites across 27 files. A script that
# reads the host journal on line 37 cannot be driven from a fixture, so the
# suite could only ever test the awk it hands the journal to. bt-phase was the
# clearest case: its analysis was well covered, and the 117-line script that
# produces the analysis's input had never run.
#
# The cost of NOT having this is on the record. bt-boot-provenance printed
# `hci=no` for all six boots — including boots whose journal plainly contains
# the device — for its entire life, because a `| grep -q` pipeline inverts under
# pipefail. It is 36 lines. One fixture would have caught it on the first run.
#
# FIXTURE LAYOUT. Files are chosen from the query, so one directory answers
# every kind of question a tool asks:
#
#   <dir>/list-boots.txt        `--list-boots`
#   <dir>/unit-<name>.log       `-u <name>` / `--unit <name>`
#   <dir>/kernel.log            `-k` / `--dmesg`
#   <dir>/default.log           anything else
#
# A `-b <boot>` selector prefers a per-boot file and falls back to the general
# one, so a fixture only spells out the boots a test actually distinguishes:
#
#   <dir>/kernel.b0.log   then   <dir>/kernel.log
#
# A MISSING FIXTURE FILE IS AN EMPTY JOURNAL, NOT AN ERROR. That is the honest
# analogue: asking a real journal for a unit that never logged returns nothing
# and exits 0. It also means a test that forgets a file sees a tool reporting
# "no records", which is a legible outcome rather than a crash.
#
# This file is SOURCED, so it must not set shell options, define traps, or run
# anything at load time — its callers set their own `set -uo pipefail` and would
# inherit whatever it changed.

# "Is a journal reachable at all?" belongs to the seam, not to its callers. The
# seam decides WHERE the journal comes from, so it is the only thing that can
# answer whether there is one; a caller asking `command -v journalctl` is asking
# about the host even when the host is not the source, and would refuse to run
# over a fixture on a machine that has no systemd.
bt_journal_available() {
    [[ -n "${BT_JOURNAL_FIXTURE:-}" ]] && return 0
    command -v journalctl >/dev/null 2>&1
}

bt_journal() {
    if [[ -z "${BT_JOURNAL_FIXTURE:-}" ]]; then
        journalctl "$@"
        return $?
    fi

    local dir="$BT_JOURNAL_FIXTURE"
    local unit="" boot="" base="default" kernel=0 listboots=0

    # Only the selectors that choose a FILE are parsed. Everything else —
    # --no-pager, -o short-iso-precise, -n, --until — is formatting or
    # narrowing that a fixture answers by simply being the text it is.
    while (( $# )); do
        case "$1" in
            --list-boots)   listboots=1; shift ;;
            -k|--dmesg)     kernel=1; shift ;;
            -u|--unit)      unit="${2:-}"; shift 2 || shift ;;
            -u*)            unit="${1#-u}"; shift ;;
            --unit=*)       unit="${1#--unit=}"; shift ;;
            -b|--boot)      boot="${2:-}"; shift 2 || shift ;;
            -b*)            boot="${1#-b}"; shift ;;
            --boot=*)       boot="${1#--boot=}"; shift ;;
            -t|--identifier) unit="t-${2:-}"; shift 2 || shift ;;
            *)              shift ;;
        esac
    done

    if   (( listboots ));    then base="list-boots"
    elif [[ -n "$unit" ]];   then base="unit-$unit"
    elif (( kernel ));       then base="kernel"
    fi

    # `-b all` is a range, not a boot: it must not become kernel.ball.log.
    local cand
    if [[ -n "$boot" && "$boot" != "all" ]]; then
        cand="$dir/$base.b$boot.log"
        [[ -r "$cand" ]] && { cat "$cand"; return 0; }
    fi
    for cand in "$dir/$base.log" "$dir/$base.txt"; do
        [[ -r "$cand" ]] && { cat "$cand"; return 0; }
    done
    return 0
}
