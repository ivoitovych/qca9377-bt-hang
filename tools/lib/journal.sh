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
# TWO TEST STRATEGIES COEXIST IN THIS TREE, ON PURPOSE. Tools that only READ
# the journal (bt-phase, bt-postmortem, bt-env-history, ...) are driven
# through this seam: a fixture directory stands in for the journal and
# nothing else about the environment matters. Tools that also ACT on the
# system (bt-trial, bt-window, bt-incident) are driven in a PATH-stub sandbox
# instead, because their risk is not "reads the wrong journal" but "resets a
# real controller / writes into the real evidence tree", and only a stubbed
# PATH plus redirected BT_* roots contains that. Converting an actuating tool
# to this seam would cover its journal reads while leaving its actions live
# under test — the more dangerous half. So a tool appearing in UT-10's
# "not converted" list is not necessarily a gap; it may be sandboxed by the
# other strategy (review 2026-08-15T1752Z §3.4).
#
# This file is SOURCED, so it must not set shell options, define traps, or run
# anything at load time — its callers set their own `set -uo pipefail` and would
# inherit whatever it changed.

# ── WHAT AN INTERVENTION LOOKS LIKE IN THE JOURNAL ───────────────────────
#
# Here, once, because every hand-written copy of these has been wrong in the
# same direction: matched on WHAT OUR TOOLING LOGS rather than on what the
# KERNEL logs. That is the same mistake as `PATH="$STUB:/usr/bin"` and the
# a.rules fixture — a pattern written on a machine where the other half never
# appears — and this is its fifth instance.
#
# bt-window carried its own copies and both were wrong at once, in opposite
# directions, on the investigation machine on 2026-08-15:
#
#   FALSE NEGATIVE  a real USBDEVFS_RESET was INVISIBLE. The copy matched
#                   `Resetting usb device`, which is bt-hang-watchdog's wording;
#                   the kernel writes `usb 3-3: reset full-speed USB device
#                   number 2 using xhci_hcd`. A window ended by a raw reset with
#                   no rfkill traffic would have read "no intervention" — the
#                   exact failure the tool had been rewritten to prevent.
#   FALSE POSITIVE  a PASSIVE rfkill observation counted as an operator action.
#                   `RFKILL event idx 0 type 2 op 1 soft 0 hard 0` is bluetoothd
#                   watching the switch disappear as the device is torn down —
#                   op 1 is RFKILL_OP_DEL, and `soft 0 hard 0` says nothing was
#                   blocked. It is a CONSEQUENCE of the reset, not a cause.
#
# They cancelled on that window: correctly CENSORED, entirely the wrong reason.
# Two errors that cancel are worse than one that does not, because the output
# looks right and nothing prompts anyone to check.
#
# Both facts were already in this tree, in tools/bt-actions — it matches the
# kernel's `reset full-speed USB device`, and it separates `soft 1` from
# `soft 0`. The knowledge was not missing; it was not shared.
#
# TOOLING interventions: this project acting on the controller. The kernel's
# reset wording covers all three speeds; usb_queue_reset_device is the request,
# `reset …-speed USB device` is the kernel carrying it out, and only the second
# appears for a reset issued by ioctl from outside this project.
BT_RE_INTERVENTION_TOOL='deregistering interface driver btusb|usb_queue_reset_device|Resetting usb device|reset (full|high|low)-speed USB device|intervening|EARLY intervention'

# OPERATOR interventions: a person reaching the controller without a terminal.
# Qualified by an ACTUAL BLOCK — `soft 1` or `hard 1` — because bare `RFKILL
# event` fires on teardown and would count the fault's own aftermath as its
# cause.
BT_RE_INTERVENTION_USER='name hci[0-9]+ blocked|powering off device on rfkill|RFKILL event.*(soft 1|hard 1)'

# "Is a journal reachable at all?" belongs to the seam, not to its callers. The
# seam decides WHERE the journal comes from, so it is the only thing that can
# answer whether there is one; a caller asking `command -v journalctl` is asking
# about the host even when the host is not the source, and would refuse to run
# over a fixture on a machine that has no systemd.
bt_journal_available() {
    [[ -n "${BT_JOURNAL_FIXTURE:-}" ]] && return 0
    command -v journalctl >/dev/null 2>&1
}

# "Can the source filter server-side?" belongs here for the same reason
# bt_journal_available does: the seam decides WHERE the journal comes from, so
# it is the only thing that can say what that source supports. A caller probing
# `journalctl --help` itself would be asking about the host even when the host
# is not the source — and would be a converted tool reaching around the seam,
# which the suite rejects by invariant.
#
# --grep is an OPTIMISATION ONLY. Callers must still match locally, because a
# fixture answers with the whole file and an older journalctl has no --grep. It
# earns its place on a large boot: journalctl formats and writes only matching
# entries, instead of handing every line of fourteen hours to a pipe.
bt_journal_supports_grep() {
    [[ -n "${BT_JOURNAL_FIXTURE:-}" ]] && return 1
    local h
    h=$(journalctl --help 2>/dev/null || true)
    [[ "$h" == *"--grep"* ]]
}

# ── COUNTING OVER A WHOLE BOOT, WITHOUT READING A WHOLE BOOT ─────────────
#
# "How many command timeouts this boot" is the one question that genuinely
# cannot be bounded — it needs the boot. It can still be made cheap, and it has
# to be, because this defect has now cost this project three separate things:
#
#   bt-trial   an unbounded scan sat between the auxiliary files and the results
#              row; systemd's stop timeout killed the close mid-way and the
#              record of the project's longest untreated window was lost (ed82166)
#   bt-window  five scans per invocation, two unbounded; it timed out during a
#              live window at the moment the window became interesting
#   snapshot   bt-health-snapshot runs every 15 minutes and scans the whole
#              kernel journal twice each time, so the cost grows for the life of
#              the boot on the machine carrying the experiment
#
# Three instances is where this repository stops fixing sites and fixes the
# shape. --grep filters INSIDE journalctl: non-matching entries are never
# formatted, never written, never piped. On a long boot with dynamic debug on,
# that is the difference between minutes and under a second.
#
# The local match still decides, so a fixture (where the seam ignores --grep)
# and an older journalctl give the same answer through the same code — the
# server-side filter is an optimisation and never the semantics.
#
# Counted rather than `grep -q` for the reason the whole repository counts:
# `grep -c` exits 1 on zero matches, so under pipefail the caller would fail
# exactly when the answer is "none", which is the common case.
bt_journal_count() {   # <ere> <journalctl selector args...>
    local re="$1"; shift
    local g=() n
    bt_journal_supports_grep && g=(--grep="$re")
    n=$(bt_journal "$@" "${g[@]}" --no-pager 2>/dev/null | grep -cE "$re" || true)
    echo "${n:-0}"
}

# The other unbounded question, and the last one: "when did this first happen?"
# — the onset of a fault, which cannot be bounded because finding it is the
# point. Same treatment, and here for the same reason: bt-window open-coded the
# --grep dance itself, which left a whole-boot read that the suite's own rule
# then had to make an exception for. An exception in a rule about whole-boot
# reads is where the next one hides, so the caller does not get to open-code it.
# And the third form: every matching line, for a caller that needs to take more
# than one count from the same window. bt-trial-audit wants three — resets,
# reloads and timeouts — and its first version read the window UNFILTERED and
# piped it to grep three times. On the investigation machine that meant scanning
# a 3h22m boot carrying dynamic-debug output at roughly a million lines an hour,
# to count a handful of matches: minutes per row, and the tool was hours old
# when it reproduced the exact defect it had been written after.
#
# One read, filtered inside journalctl by the UNION of the patterns, then
# counted locally per pattern. The union is what makes this safe: the local
# match still decides, and it can only ever select a subset of what came back.
bt_journal_lines() {   # <ere> <journalctl selector args...> — the matching lines
    local re="$1"; shift
    local g=()
    bt_journal_supports_grep && g=(--grep="$re")
    bt_journal "$@" "${g[@]}" --no-pager 2>/dev/null | grep -E "$re"
}

bt_journal_first() {   # <ere> <journalctl selector args...> — first match, or empty
    local re="$1"; shift
    local g=()
    bt_journal_supports_grep && g=(--grep="$re")
    bt_journal "$@" "${g[@]}" --no-pager 2>/dev/null | grep -m1 -E "$re"
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
