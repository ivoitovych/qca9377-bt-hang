# timestamp.awk — one civil-date implementation, shared by every analysis tool.
#
# WHY A SHARED FILE. Three tools grew their own timestamp parser. Two of them
# computed seconds as (day_of_month * 24 + hour) * 3600 + ..., which ignores
# year and month entirely. Inside a single day that is correct; across
# 2026-08-31 23:59:59 -> 2026-09-01 00:00:02 it produces a large negative
# interval, and nothing in the output would look wrong.
#
# bt-phase was fixed in isolation, which left the other two wrong AND created a
# second, subtly different implementation to maintain. Loading this file with
# `awk -f tools/lib/timestamp.awk -f <script>` means there is one.
#
# iso_secs() accepts the forms these tools actually see:
#   2026-08-12T19:14:47.359513+02:00     journalctl short-iso-precise
#   2026-08-12 19:14:47.359              btmon -T
# and returns seconds since the Unix epoch as a double, keeping sub-second
# precision. A trailing ±HH:MM offset is applied (normalising to UTC), so a
# session spanning a DST transition — twice a year in this machine's zone —
# computes correct intervals. Offset-less forms (btmon -T) remain naive local
# time; no caller compares an offset-carrying timestamp against a naive one.

function _days_from_civil(y, m, d,   era, yoe, doy, doe) {
    # Howard Hinnant's days_from_civil. Correct for any proleptic Gregorian
    # date, which matters because the alternative — arithmetic on day-of-month —
    # is exactly the bug this file exists to remove.
    if (m <= 2) y--
    era = int((y >= 0 ? y : y - 399) / 400)
    yoe = y - era * 400
    doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1
    doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
    return era * 146097 + doe - 719468
}

function iso_secs(t,   sep, dpart, tpart, a, b, i, off, sgn) {
    sep = (index(t, "T") ? "T" : " ")
    i = index(t, sep)
    if (i == 0) return -1
    dpart = substr(t, 1, i - 1)
    tpart = substr(t, i + 1)
    split(dpart, a, "-")
    if (a[1] + 0 < 1970) return -1
    split(tpart, b, ":")
    # A trailing +HH:MM / -HH:MM offset is now APPLIED, not dropped. The header
    # note "offsets cancel on one host" was true until the host's own clock
    # moved: this machine's zone (CET/CEST) changes offset twice a year, and a
    # session spanning the transition would have had every interval wrong by
    # exactly 3600 s while looking plausible. Timestamps with an offset are
    # normalised to UTC; timestamps without one (btmon -T) stay naive local
    # time — the two forms are never compared against each other by any caller
    # here (each comparison draws both sides from one source).
    # ([0-9][0-9] rather than {2}: interval expressions are the construct some
    # awks silently mishandle — see tools/sanitize-logs.sh — and this file must
    # parse everywhere.)
    off = 0
    if (match(tpart, /[+-][0-9][0-9]:[0-9][0-9]$/)) {
        sgn = (substr(tpart, RSTART, 1) == "-") ? -1 : 1
        off = sgn * (substr(tpart, RSTART + 1, 2) * 3600 + substr(tpart, RSTART + 4, 2) * 60)
    }
    # b[3] may carry a fractional part and the offset suffix; + 0 stops at the
    # first non-numeric character.
    return _days_from_civil(a[1] + 0, a[2] + 0, a[3] + 0) * 86400 \
           + b[1] * 3600 + b[2] * 60 + b[3] + 0 - off
}
