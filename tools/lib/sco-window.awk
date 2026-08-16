# sco-window.awk — print every capture line within ±win seconds of each
# Setup Synchronous Connection request. Loaded by bt-sco --window as
#
#   awk -v win=<s> -f tools/lib/timestamp.awk -f tools/lib/sco-window.awk <dump> <dump>
#
# (two passes over the same file: marks first, then selection).
#
# Extracted from an inline program in tools/bt-sco that carried a private
# days()/ts() copy of the civil-date arithmetic (review 2026-08-15T1752Z
# §3.1). Full civil date, not seconds-since-midnight: captures routinely span
# several days, and a window near midnight would otherwise splice unrelated
# dates — in the tool whose purpose is comparing event PATHS.
#
# btmon -T timestamps are naive local time; both sides of every comparison
# here come from the same stream, so no offset-carrying timestamp is ever
# compared against them (the caveat timestamp.awk's header states).

function ts(line) {
    if (match(line, /[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+/) == 0)
        return -1
    return iso_secs(substr(line, RSTART, RLENGTH))
}
NR == FNR {
    if ($0 ~ /HCI Command: Setup Synchronous Connection/) {
        t = ts($0); if (t >= 0) marks[++m] = t
    }
    next
}
{
    t = ts($0)
    if (t >= 0) cur = t          # continuation lines inherit the last stamp
    for (i = 1; i <= m; i++)
        if (cur >= marks[i] - win && cur <= marks[i] + win) { print; next }
}
