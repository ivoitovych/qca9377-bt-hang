# unit-state-changes.awk — what a deploy changed in the project's units.
#
#   awk -f tests/unit-state-changes.awk <before> <after>
#
# Each input line is "unit enabled-state up|down active/sub", as
# tests/system-upgrade's unit_states() prints it; the fourth field is shown,
# not compared. Prints one line per change and nothing when the deploy
# started, stopped, enabled or disabled nothing:
#   changed — a unit listed before differs in enabled-state or in up/down;
#   gone    — a unit listed before is not listed after;
#   armed   — a unit the deploy installed is enabled, or is up.
#
# A unit the new tree adds (bt-raw-archive.service and .timer, 2026-11-13) is
# a file the deploy wrote, which --tools-only is for. Installed disabled or
# static, and down, it is not a state the deploy changed; enabled or running,
# it is. Comparing the two lists as text read the first as the second.
FILENAME == ARGV[1] {
    if (NF) { before[$1] = $1 " " $2 " " $3; line[$1] = $0 }
    next
}
NF == 0 { next }
{
    seen[$1] = 1
    if ($1 in before) {
        if ($1 " " $2 " " $3 != before[$1])
            printf "changed: %s  (was: %s)\n", $0, line[$1]
    } else if (($2 != "disabled" && $2 != "static") || $3 != "down") {
        printf "armed: %s  (not listed before)\n", $0
    }
}
END {
    for (u in before)
        if (!(u in seen))
            printf "gone: %s\n", line[u]
}
