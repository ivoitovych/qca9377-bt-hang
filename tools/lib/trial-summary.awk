# trial-summary.awk — loaded by bt-trial with `awk -f`.
#
# KEPT IN A FILE, NOT AS AN INLINE SHELL STRING. Three reasons, each of
# which cost this project something:
#
#   * Shell quoting cannot corrupt the program. Inline, the whole thing is a
#     single-quoted string, so one apostrophe in a comment ends it and
#     produces a bash syntax error dozens of lines away.
#   * The program can be SYNTAX-CHECKED. An earlier inline version of the
#     SCO table had a braceless `if` followed by `else`, so the entire END
#     block was a parse error and had never executed. Nothing checked it,
#     because nothing could.
#   * `awk -f` gives a directly observable exit status, and the tests can
#     drive the exact file production drives rather than a copy.
#
# Fields are addressed BY HEADER NAME. Adding a column must never change
# what is counted; tests/run-tests permutes the header and requires the
# report to be byte-identical.

BEGIN { FS = "\t" }
NR == 1 { for (i = 1; i <= NF; i++) c[$i] = i; next }
{
    ty = (c["trial_type"] ? $c["trial_type"] : "unknown_pre_schema")
    b  = $c["build"]; k = ty "|" b
    tot[k]++; if ($c["outcome"] == "hang") h[k]++; sum[k] += $c["duration_s"]
}
END {
    printf "  %-20s %-8s %-10s %-8s %s\n", "TRIAL TYPE", "BUILD", "HANGS", "RATE", "mean duration"
    for (k in tot) {
        split(k, p, "|")
        rate = 100 * (h[k] + 0) / tot[k]
        printf "  %-20s %-8s %-10s %-8s %.0fs\n", p[1], p[2],
               (h[k] + 0) "/" tot[k], sprintf("%.0f%%", rate), sum[k] / tot[k]
    }
    print ""
    print "  These rows must never be added together. An observational boot"
    print "  and a controlled protocol run are different evidence: the first"
    print "  says the machine did or did not hang during ordinary use, the"
    print "  second says the reproduction protocol was applied and the"
    print "  controller withstood it or did not. Only controlled_* rows can"
    print "  satisfy the A/B/C/D gate."
}
