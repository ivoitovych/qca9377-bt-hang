# phase.awk — loaded by bt-phase with `awk -f`.
#
#   awk -v igap=<s> -v period=<s> \
#       -f tools/lib/timestamp.awk -f tools/lib/phase.awk <records>
#
# Records are "<boot> <kind> <iso-timestamp>", kind in EXO / ENDO / TMO. Boot is
# carried explicitly so nothing is ever compared across a reboot.
#
# WHY THIS IS A FILE NOW, AND NOT AN INLINE STRING IN bt-phase.
#
# It was inline, and the suite tested it by running a PYTHON REGEX OVER
# bt-phase's SOURCE to pull the program back out:
#
#     re.search(r"awk -v igap=\"\$INCIDENT_GAP\" ... '(.*)' \"\$DATA\"", s, re.S)
#
# So the test ran a copy reconstructed from the tool, not the program the tool
# runs. This repository has already been bitten by exactly that: an extracted
# copy of bt-capdiff's matcher worked in the test while the shipped invocation
# silently loaded nothing, and bt-capdiff reported perfect agreement between
# paths differing by 278 records. capdiff-match.awk was moved to lib/ to escape
# it; bt-phase was the last holdout. `devtools/coverage` put a number on the
# cost — 0.0% of bt-phase's 117 lines had ever executed under test.
#
# The other two reasons are the ones trial-summary.awk already records: shell
# quoting cannot corrupt a file (one apostrophe in a comment ended the
# single-quoted string and produced a bash error dozens of lines away — this
# program carried `boot'"'"'s` to work around it), and a file can be
# syntax-checked by repo-validate, which an inline string cannot.
#
# THE DATE ARITHMETIC IS NO LONGER PRIVATE. This program carried its own
# days()/s() pair, duplicating _days_from_civil()/iso_secs() in timestamp.awk.
# That shared file exists precisely because "bt-phase was fixed in isolation,
# which left the other two wrong AND created a second, subtly different
# implementation to maintain" — its own header says so. bt-phase was still
# running the second implementation. It now calls iso_secs() like everything
# else, which also gains that function's guards: a year before 1970 or a
# missing date/time separator returns -1 rather than silently computing a
# number from a malformed record.

{
    boot = $1; kind = $2; t = iso_secs($3)
    if (kind == "EXO")  { ne[boot]++; exo[boot, ne[boot]] = t }
    if (kind == "ENDO") { nendo[boot]++ }
    if (kind == "TMO")  { nt[boot]++;  tmo[boot, nt[boot]] = t }
    boots[boot] = 1
}
END {
    for (b in boots) {
        # --- sort this boot's exogenous probes ----------------------------
        n = ne[b] + 0
        for (i = 1; i <= n; i++) e[i] = exo[b, i]
        for (i = 2; i <= n; i++) { v = e[i]; j = i - 1
            while (j > 0 && e[j] > v) { e[j+1] = e[j]; j-- } ; e[j+1] = v }

        # --- provenance self-check ----------------------------------------
        # Provenance by unit name exists only for data recorded after the units
        # were split. Older boots put both sources in one unit and would present
        # as entirely exogenous. The timer period makes that checkable: a
        # genuinely timer-driven sequence cannot contain short gaps.
        short = 0
        for (i = 2; i <= n; i++) if (e[i] - e[i-1] < period / 2) short++
        if (short > 0) { bad[b] = short; totbad++; continue }

        # --- collapse timeout lines into incidents ------------------------
        m = nt[b] + 0
        for (i = 1; i <= m; i++) f[i] = tmo[b, i]
        for (i = 2; i <= m; i++) { v = f[i]; j = i - 1
            while (j > 0 && f[j] > v) { f[j+1] = f[j]; j-- } ; f[j+1] = v }
        inc = 0
        for (i = 1; i <= m; i++)
            if (i == 1 || f[i] - f[i-1] >= igap) { inc++; first[inc] = f[i] }
        lines[b] = m; incidents[b] = inc; totinc += inc; totlines += m

        # --- place each incident in its exogenous gap ---------------------
        for (k = 1; k <= inc; k++) {
            lo = 0; hi = 0
            for (i = 1; i <= n; i++) {
                if (e[i] <= first[k]) lo = e[i]
                if (e[i] >  first[k]) { hi = e[i]; break }
            }
            if (lo == 0 || hi == 0) { edge++; continue }
            gap = hi - lo
            if (gap <= 0) continue
            ph = (first[k] - lo) / gap
            printf "  boot %-4s phase %.3f   (%.1fs into a %.1fs gap)\n", b, ph, first[k] - lo, gap
            total++; sum += ph
            if (ph < 0.10) near++
            bucket[int(ph * 5)]++
        }
        for (i in e) delete e[i]
        for (i in f) delete f[i]
        for (i in first) delete first[i]
    }

    print ""
    if (totbad) {
        printf "  ⛔ %d boot(s) SKIPPED — provenance check failed.\n", totbad
        print  "     Timer-driven probes cannot be closer than half the timer"
        print  "     period. Those boots predate the split of"
        print  "     bt-health-snapshot.service from -event.service, so udev and"
        print  "     timer probes are indistinguishable and the baseline is"
        print  "     contaminated. Reporting a number for them would repeat EX-012."
        print  ""
    }
    printf "  timeout LINES      %d\n", totlines + 0
    printf "  timeout CLUSTERS   %d   <- grouped by a %ds gap, NOT proven incidents\n", totinc + 0, igap
    if (edge) printf "  outside probe range %d (excluded)\n", edge
    print ""
    if (total == 0) {
        print "  No timeout cluster could be placed inside a timer-driven probe gap."
        print "  Nothing to report — this is a coverage statement, not a result."
        exit
    }
    printf "  placed             %d\n", total
    printf "  mean phase         %.3f   (0.5 expected under independence)\n", sum / total
    printf "  within first 10%%   %d of %d\n", near + 0, total
    print ""
    print "  distribution across the gap:"
    for (i = 0; i <= 4; i++)
        printf "    %.1f-%.1f  %s\n", i / 5, (i + 1) / 5, (bucket[i] ? bucket[i] : 0)
    print ""
    if (total < 8) {
        print "  ⚠ Too few events for this to mean anything. Recorded so the"
        print "    question can be answered later, not so it can be answered now."
    } else if (near > total * 0.5) {
        print "  ⚠ Over half the clusters fall in the first 10% of their gap."
        print "    Not expected under independence; worth investigating."
    } else {
        print "  No evidence of an observer effect in this data. Note that this"
        print "  is an absence of evidence for clustering, NOT a demonstration"
        print "  of independence — with few events it cannot be that."
    }
}
