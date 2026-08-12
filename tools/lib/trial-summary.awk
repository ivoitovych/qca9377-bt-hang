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
    split("build outcome duration_s environment", need, " ")
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
    b  = $c["build"]
    # THE ENVIRONMENT IS PART OF THE TREATMENT, so it is part of the key.
    # `build=stock` names the kernel only. Trials taken with autosuspend
    # disabled, or with a recovery watchdog able to rescue the controller, are
    # not the same experiment as trials taken without — pooling them under one
    # build name produces a denominator that mixes treatments silently.
    e  = $c["environment"]
    k  = ty "|" b "|" e
    envs[e] = 1
    # DOMAIN CHECK. An unrecognised outcome must not be silently folded into
    # "not hung". Miscounting a failure as a survival moves the denominator in
    # the direction that makes any build look better, which is the one
    # direction an error here must never take.
    o = $c["outcome"]
    if (o != "hang" && o != "ok" && o != "survived" && o != "recovered") {
        printf "trial-summary: unrecognised outcome \"%s\" on line %d\n", o, NR > "/dev/stderr"
        print  "  Refusing to report rather than counting it as a survival." > "/dev/stderr"
        abort = 1; exit 1
    }
    tot[k]++; sum[k] += $c["duration_s"]
    # Two different questions, kept apart:
    #   h[]   BT-1 reached UNRECOVERED failure (cold power-off needed)
    #   inc[] BT-1 OCCURRED at all — hang plus watchdog-rescued
    # Reporting only h[] would understate the incidence of the bug by exactly
    # the watchdog success rate, which is the quantity the mitigation exists to
    # maximise. A build could then look better purely because recovery worked.
    if (o == "hang")      { h[k]++;   inc[k]++ }
    if (o == "recovered") { rec[k]++; inc[k]++ }
}
END {
    # awk runs END even after `exit` from another rule, so a refusal would
    # still print the table it is refusing to justify — the caller would see
    # a plausible report AND a non-zero status, and the report is what gets
    # read. Bail before printing anything.
    if (abort) exit 1
    printf "  %-20s %-7s %-9s %-9s %-8s %s\n", "TRIAL TYPE", "BUILD", "UNRECOV", "BT-1 INC", "RATE", "mean dur"
    for (k in tot) {
        split(k, p, "|")
        rate = 100 * (inc[k] + 0) / tot[k]
        printf "  %-20s %-7s %-9s %-9s %-8s %.0fs\n", p[1], p[2],
               (h[k] + 0) "/" tot[k], (inc[k] + 0) "/" tot[k],
               sprintf("%.0f%%", rate), sum[k] / tot[k]
        printf "      env: %s\n", p[3]
    }
    print ""
    print "  These rows must never be added together. An observational boot"
    print "  and a controlled protocol run are different evidence: the first"
    print "  says the machine did or did not hang during ordinary use, the"
    print "  second says the reproduction protocol was applied and the"
    print "  controller withstood it or did not. Only controlled_* rows can"
    print "  satisfy the A/B/C/D gate."

    ne = 0
    for (e in envs) ne++
    if (ne > 1) {
        print ""
        printf "  !! %d DISTINCT ENVIRONMENTS above.\n", ne
        print  "     Rows with different env: lines are different EXPERIMENTS and must"
        print  "     not be added together. Autosuspend state and watchdog mode change"
        print  "     the controller and can change the outcome, so a kernel comparison"
        print  "     across them measures the mitigation as much as the kernel."
        print  "     `build` names only the kernel; the treatment is build + env."
    }
}
