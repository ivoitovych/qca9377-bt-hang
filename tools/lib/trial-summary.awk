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
    split("build bt1_status trial_result duration_s treatment", need, " ")
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
    # THE TREATMENT IS PART OF THE KEY; the measurement revision is NOT.
    # `build=stock` names the kernel only. Trials taken with autosuspend
    # disabled, or with a recovery watchdog able to rescue the controller, are
    # not the same experiment as trials taken without — pooling them under one
    # build name produces a denominator that mixes treatments silently.
    e  = $c["treatment"]
    k  = ty "|" b "|" e
    envs[e] = 1
    # A trial whose treatment changed mid-run was not conducted under one
    # condition. It is counted and shown, never pooled into a rate — the same
    # discipline as a censored observation, applied to the treatment axis.
    # EXCLUDED, not merely unpooled. A unique treatment key stops it mixing
    # with other trials but still gives it its own one-row denominator and a
    # rate — and a trial reconfigured while running was not conducted under any
    # single condition, so no rate computed from it means anything. The comment
    # said "cannot enter a controlled rate"; without this `next` it did.
    if (e ~ /^CHANGED:/) { drift[k]++; seen[k]++; next }
    if (c["measurement_rev"]) mrevs[$c["measurement_rev"]] = 1
    # DOMAIN CHECK. An unrecognised outcome must not be silently folded into
    # "not hung". Miscounting a failure as a survival moves the denominator in
    # the direction that makes any build look better, which is the one
    # direction an error here must never take.
    # Both axes are domain-checked. An unrecognised value must not be folded
    # into whichever bucket looks harmless — miscounting a failure as a
    # survival moves the denominator in the direction that makes any build look
    # better, which is the one direction an error here must never take.
    bs = $c["bt1_status"]
    if (bs != "not_observed" && bs != "confirmed" && bs != "censored_pre_failure" && bs != "unknown") {
        printf "trial-summary: unrecognised bt1_status \"%s\" on line %d\n", bs, NR > "/dev/stderr"
        abort = 1; exit 1
    }
    tr = $c["trial_result"]
    if (tr != "survived" && tr != "failed" && tr != "alive_after_intervention" && tr != "aborted") {
        printf "trial-summary: unrecognised trial_result \"%s\" on line %d\n", tr, NR > "/dev/stderr"
        abort = 1; exit 1
    }
    # CENSORED rows are counted, shown, and EXCLUDED FROM THE RATE. An early
    # watchdog intervention before any observed timeout destroyed the
    # counterfactual: the controller might have wedged, or might have been
    # fine. Putting them in the numerator lets the mitigation manufacture the
    # incidence it is measuring; putting them in the denominator understates
    # it. They belong in neither, and must stay visible so the denominator is
    # never quietly smaller than the sample.
    # Censored and unknown evidence cannot enter a BT-1 rate in either
    # direction; they are counted, shown, and excluded from the denominator.
    if (bs == "censored_pre_failure") { cen[k]++; seen[k]++; next }
    if (bs == "unknown")              { unk[k]++; seen[k]++; next }
    tot[k]++; sum[k] += $c["duration_s"]; seen[k]++
    # Two different questions, kept apart:
    #   h[]   BT-1 reached UNRECOVERED failure (cold power-off needed)
    #   inc[] BT-1 OCCURRED at all — hang plus watchdog-rescued
    # Reporting only h[] would understate the incidence of the bug by exactly
    # the watchdog success rate, which is the quantity the mitigation exists to
    # maximise. A build could then look better purely because recovery worked.
    # THE NUMERATOR IS MECHANICAL: the defect occurred iff the evidence says
    # so. Whether the controller was subsequently rescued is a different fact,
    # on the other axis, and does not change whether BT-1 happened.
    if (bs == "confirmed") {
        inc[k]++
        if (tr == "failed")    h[k]++      # confirmed and unrecovered
        if (tr == "alive_after_intervention") rec[k]++   # confirmed, then rescued
    }
}
END {
    # awk runs END even after `exit` from another rule, so a refusal would
    # still print the table it is refusing to justify — the caller would see
    # a plausible report AND a non-zero status, and the report is what gets
    # read. Bail before printing anything.
    if (abort) exit 1
    printf "  %-18s %-6s %-8s %-8s %-7s %-8s %s\n", "TRIAL TYPE", "BUILD", "UNRECOV", "BT-1 INC", "RATE", "CENSORED", "mean dur"
    for (k in tot) {
        split(k, p, "|")
        rate = (tot[k] ? 100 * (inc[k] + 0) / tot[k] : 0)
        printf "  %-18s %-6s %-8s %-8s %-7s %-8s %.0fs\n", p[1], p[2],
               (h[k] + 0) "/" (tot[k] + 0), (inc[k] + 0) "/" (tot[k] + 0),
               (tot[k] ? sprintf("%.0f%%", rate) : "n/a"),
               (cen[k] + 0) "/" (seen[k] + 0), (tot[k] ? sum[k] / tot[k] : 0)
        printf "      treatment: %s\n", p[3]
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

    tc = 0
    for (k in cen) tc += cen[k]
    if (tc > 0) {
        print ""
        printf "  !! %d CENSORED trial(s), excluded from every rate above.\n", tc
        print  "     An early watchdog intervention fired before any timeout was"
        print  "     observed, so the natural outcome is unknowable: the controller"
        print  "     might have wedged, or might have been fine. Early precursors in"
        print  "     this project have repeatedly turned out NOT to be causal, so an"
        print  "     early intervention is not evidence that BT-1 was imminent."
        print  "     For a controlled comparison, run with the watchdog OFF."
    }

    td = 0
    for (k in drift) td += drift[k]
    if (td > 0) {
        print ""
        printf "  !! %d trial(s) whose TREATMENT CHANGED mid-run.\n", td
        print  "     Their treatment string begins CHANGED: so it matches no other"
        print  "     trial and cannot pool into any denominator. A trial that was"
        print  "     reconfigured while running was not conducted under one"
        print  "     condition, and no rate computed from it means anything."
    }
}
