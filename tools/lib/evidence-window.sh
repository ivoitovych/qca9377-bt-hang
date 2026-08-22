# evidence-window.sh — the one grammar for "what instants does this exhibit cover?"
#
#   source "$LIBDIR/evidence-window.sh"
#   bt_ew_render  <text-file>        # derive the field line from captured output
#   bt_ew_read    <exhibit-file>     # the declared field's payload, or empty
#   bt_ew_earliest "<payload>"       # the earliest instant in a payload, or empty
#
# WHY THIS EXISTS (BL-09). `bt-retention` answers "can this exhibit still be
# re-verified against the journal?" by placing it on journald's absolute axis.
# Nine of twenty-nine exhibits could not be placed at all: their bodies are
# written in bare local time, and the only offset-carrying stamp in the file was
# `captured` in the provenance table — which is when the command RAN, not when
# the evidence happened. For a retrospective exhibit those are weeks apart, and
# reading one as the other reported EX-018 as retained while the windows it
# describes had already rotated away. That is the defect this field exists
# because of.
#
# TWO TOOLS, ONE GRAMMAR, AND THAT IS THE POINT OF THIS FILE. `bt-exhibit`
# writes the field and `bt-retention` reads it, and a writer and a reader with
# separate copies of a format agree exactly until one of them is edited. The
# suite drives an exhibit through both and asserts the round trip, which is a
# check neither tool could make about itself.
#
# ── THE FIELD ────────────────────────────────────────────────────────────
#
#   **Evidence window.** `<first>` — `<last>`      a closed window
#   **Evidence window.** `<instant>`               a single instant
#   **Evidence window.** not placeable — <reason>  examined, and it cannot be done
#
# ABOVE `## Provenance`, ALWAYS. `bt-retention` truncates the file at that
# heading before it looks at anything, and BL-09's recorded decision is to keep
# that cut blunt rather than teach it field names:
#
#   * a blunt cut that drops a field fails to **not judgeable** — a missing
#     answer, visible, and it prompts someone to look;
#   * a parser that reads named fields out of the capture record fails to a
#     **wrong answer**, silently — which is precisely how the capture stamp came
#     to masquerade as the evidence's.
#
# So the field lives in the body, where the evidence is described, and the cut
# stays incapable of preferring the capture record over it.
#
# `not placeable` IS AN ANSWER AND ABSENCE IS NOT. An exhibit with no field has
# not been looked at; an exhibit declaring `not placeable` has, and the reason
# says why it cannot be done. `bt-retention` reports the two differently, so
# closing the gap is measurable rather than a matter of remembering which is
# which.
#
# This file is SOURCED, so it must not set shell options, define traps, or run
# anything at load time — its callers set their own `set -uo pipefail`.

# An ABSOLUTE instant: date, time, and a UTC offset. The offset is not optional
# and never becomes optional. Boot ranges are absolute epochs from journald;
# `2026-08-14T21:02:15` is not an instant until something supplies a zone, and
# the something would be the reader's own `TZ` — which put a retained exhibit
# two hours out in bt-retention's first version, enough to report evidence as
# rotated away while it was still there.
BT_EW_TS_RE='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?([+-][0-9]{2}:?[0-9]{2}|Z)'

# The literal the field opens with. Both tools match on this and nothing else,
# so it is written once.
BT_EW_PREFIX='**Evidence window.**'

# The payload of the declared field, or empty when there is no field. Reads only
# ABOVE `## Provenance` — a field below it would be part of the capture record,
# which is the thing this whole mechanism exists to stop being trusted.
bt_ew_read() {   # <exhibit-file>
    local f="$1"
    [[ -r "$f" ]] || return 0
    awk '
        /^#{1,6}[[:space:]]+Provenance[[:space:]]*$/ { exit }
        index($0, "**Evidence window.**") == 1 {
            sub(/^\*\*Evidence window\.\*\*[[:space:]]*/, "")
            print; exit
        }' "$f"
}

# The earliest instant in a payload, as an epoch — or empty when the payload
# declares `not placeable`, carries no instant, or carries one that does not
# parse.
#
# BY INSTANT, NOT BY POSITION. `head -1` would take the first stamp as WRITTEN,
# which is the earliest only while every stamp shares an offset — true of all
# 128 stamps in this tree today, and false for one date a year, when a capture
# either side of a DST change puts +01:00 and +02:00 on the same day and the
# textually-first is the later instant.
#
# A STAMP THAT DOES NOT PARSE VOIDS THE ANSWER rather than being skipped. The
# regex above accepts dates that do not exist — `2026-02-30T00:00:00+02:00` and
# `2026-08-15T25:00:00+02:00` both match it — and `date -f -` drops a line it
# cannot read and carries on. Taking the minimum of what survived would answer
# from a list missing the entry that might have been the earliest.
bt_ew_earliest() {   # <payload>
    local payload="$1" n i best
    local -a stamp epoch
    mapfile -t stamp < <(grep -oE "$BT_EW_TS_RE" <<<"$payload")
    n=${#stamp[@]}
    (( n > 0 )) || return 0
    mapfile -t epoch < <(printf '%s\n' "${stamp[@]}" | date -f - +%s 2>/dev/null)
    (( ${#epoch[@]} == n )) || return 0
    best=0
    for ((i = 1; i < n; i++)); do (( epoch[i] < epoch[best] )) && best=$i; done
    echo "${epoch[$best]}"
}

# The field line for a file of captured output. Derived from the OUTPUT, never
# from the clock: `date -Iseconds` here would be the capture time again under a
# new name, which is the bug.
bt_ew_render() {   # <text-file>
    local f="$1" n i lo hi
    local -a stamp epoch
    if [[ ! -r "$f" ]]; then
        printf '%s not placeable — the captured output could not be read.\n' "$BT_EW_PREFIX"
        return 0
    fi
    mapfile -t stamp < <(grep -oE "$BT_EW_TS_RE" "$f")
    n=${#stamp[@]}
    if (( n == 0 )); then
        printf '%s not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.\n' \
               "$BT_EW_PREFIX"
        return 0
    fi
    mapfile -t epoch < <(printf '%s\n' "${stamp[@]}" | date -f - +%s 2>/dev/null)
    if (( ${#epoch[@]} != n )); then
        printf '%s not placeable — %s of %s timestamps in this output do not parse.\n' \
               "$BT_EW_PREFIX" "$(( n - ${#epoch[@]} ))" "$n"
        return 0
    fi
    lo=0; hi=0
    for ((i = 1; i < n; i++)); do
        (( epoch[i] < epoch[lo] )) && lo=$i
        (( epoch[i] > epoch[hi] )) && hi=$i
    done
    if (( lo == hi )); then
        printf '%s `%s`\n' "$BT_EW_PREFIX" "${stamp[$lo]}"
    else
        printf '%s `%s` — `%s`\n' "$BT_EW_PREFIX" "${stamp[$lo]}" "${stamp[$hi]}"
    fi
}
