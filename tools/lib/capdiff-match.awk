# capdiff-match.awk — one-to-one pairing of records between two capture paths.
#
# Loaded with tools/lib/timestamp.awk, which supplies iso_secs().
#
# KEPT IN A FILE, NOT INLINE. `awk -f lib.awk 'program' input` does NOT run
# 'program': with -f present, awk takes the program only from the -f files and
# treats the positional string as an INPUT FILE. That mistake silently disabled
# this matcher — every record went unread, both .only files were created empty
# by a later touch, and the tool reported zero unmatched in both directions,
# i.e. perfect agreement, for paths differing by 278 records. Exactly the false
# agreement the consumptive matcher was written to prevent, reintroduced by the
# refactor that shared the date arithmetic.
function key(line,   ev) { ev = line; sub(/^[^ ]* /, "", ev); return ev }
NR == FNR {
    ev = key($0); na[ev]++; at[ev, na[ev]] = iso_secs($1); al[ev, na[ev]] = $0
    seen[ev] = 1; next
}
{
    ev = key($0); nb[ev]++; bt[ev, nb[ev]] = iso_secs($1); bl[ev, nb[ev]] = $0
    seen[ev] = 1
}
END {
    for (ev in seen) {
        i = 1; j = 1
        while (i <= na[ev] && j <= nb[ev]) {
            d = at[ev, i] - bt[ev, j]; if (d < 0) d = -d
            if (d <= tol)                    { i++; j++ }        # consume BOTH
            else if (at[ev, i] < bt[ev, j])  { print al[ev, i] > outA; i++ }
            else                             { print bl[ev, j] > outB; j++ }
        }
        while (i <= na[ev]) { print al[ev, i] > outA; i++ }
        while (j <= nb[ev]) { print bl[ev, j] > outB; j++ }
    }
}
