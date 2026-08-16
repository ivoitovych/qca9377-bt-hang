# boot-hours.awk — hours between two ISO timestamps, one decimal place.
#
#   awk -f tools/lib/timestamp.awk -f tools/lib/boot-hours.awk -v a=<first> -v b=<last>
#
# Extracted from tools/bt-boot-stats, which carried its own private copy of
# the civil-date arithmetic inside an inline program — one of three such
# copies found alongside the shared tools/lib/timestamp.awk whose header
# promises "one civil-date implementation" (review 2026-08-15T1752Z §3.1).
# The inline day-of-month ancestor of that copy printed -678.4 hours into a
# committed exhibit (EX-003); sharing iso_secs() is what ends the class.
#
# Prints nothing and exits non-zero on an unparseable timestamp, so a caller
# cannot mistake a parse failure for a zero-length boot.

BEGIN {
    sa = iso_secs(a)
    sb = iso_secs(b)
    if (sa < 0 || sb < 0) exit 1
    printf "%.1f", (sb - sa) / 3600
}
