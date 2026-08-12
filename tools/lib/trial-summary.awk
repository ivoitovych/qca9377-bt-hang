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
# REQUIRED SCHEMA. Resolving columns by name is only half the guarantee: if a
# required name is ABSENT, awk turns the lookup into field 0 or an empty value
# and the program computes plausible nonsense while exiting successfully. That
# is the same epistemic failure as reading the wrong field, arriving by a
# different route.
#
# So the schema is a precondition, checked once, and its absence is fatal. A
# report that cannot justify its own arithmetic must not print it.
#
# trial_type is deliberately NOT required: rows written before that column
# existed are still legitimate data and are labelled unknown_pre_schema.
NR == 1 {
    for (i = 1; i <= NF; i++) c[$i] = i
    split("build outcome duration_s", need, " ")
    for (k in need)
        if (!(need[k] in c)) missing = missing " " need[k]
    if (missing != "") {
        printf "trial-summary: results.tsv is missing required column(s):%s\n", missing > "/dev/stderr"
        print  "  Refusing to report. The denominators cannot be justified from this schema." > "/dev/stderr"
        abort = 1; exit 1
    }
    next
}
{
    ty = (c["trial_type"] ? $c["trial_type"] : "unknown_pre_schema")
    b  = $c["build"]; k = ty "|" b
    # DOMAIN CHECK. An unrecognised outcome must not be silently folded into
    # "not hung". Miscounting a failure as a survival moves the denominator in
    # the direction that makes any build look better, which is the one
    # direction an error here must never take.
    o = $c["outcome"]
    if (o != "hang" && o != "ok" && o != "survived") {
        printf "trial-summary: unrecognised outcome \"%s\" on line %d\n", o, NR > "/dev/stderr"
        print  "  Refusing to report rather than counting it as a survival." > "/dev/stderr"
        abort = 1; exit 1
    }
    tot[k]++; if (o == "hang") h[k]++; sum[k] += $c["duration_s"]
}
END {
    # awk runs END even after `exit` from another rule, so a refusal would
    # still print the table it is refusing to justify — the caller would see
    # a plausible report AND a non-zero status, and the report is what gets
    # read. Bail before printing anything.
    if (abort) exit 1
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
