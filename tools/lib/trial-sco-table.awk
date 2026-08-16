# trial-sco-table.awk — loaded by bt-trial with `awk -f`.
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
# REQUIRED SCHEMA — see trial-summary.awk for the reasoning.
#
# `bt1_status` is mandatory. Without it the classification below silently makes
# every row not-hung, producing a table that says the stimulus never coincided
# with a failure. That is precisely the wrong answer this cross-tab exists to
# avoid, delivered with a clean exit status.
#
# `sco_sent` is optional on purpose: rows recorded before the SCO fields were
# tracked are real trials, and the code represents them as "?" rather than
# pretending to know. That is a deliberate unknown, not a missing precondition.
NR==1 {
    for (i=1; i<=NF; i++) col[$i] = i
    if (!("treatment" in col)) {
        print "trial-sco-table: results.tsv has no `treatment` column." > "/dev/stderr"
        print "  Refusing: trials reconfigured mid-run cannot be identified." > "/dev/stderr"
        abort = 1; exit 1
    }
    if (!("bt1_status" in col)) {
        print "trial-sco-table: results.tsv has no `bt1_status` column." > "/dev/stderr"
        print "  Refusing to report: every row would be classified as survived." > "/dev/stderr"
        abort = 1; exit 1
    }
    next
}
{
    # BY HEADER NAME, NEVER BY POSITION. This line read `$5 == "hang"`
    # until 2026-08-13. Inserting trial_type made field 5 `protocol`, so the
    # test was always false and EVERY hang in this cross-tab was silently
    # classified as survived — while the denominator table thirty lines
    # above, which does resolve by name, stayed correct.
    #
    # That is the second defect caused by one schema change (next_trial_no
    # was the first), in a file whose own comments state the rule. Hence
    # tests/run-tests permutes the header and asserts the report is
    # unchanged: positional assumptions are then mechanically impossible
    # rather than merely discouraged.
    s = (col["sco_sent"]  ? $col["sco_sent"]  : "?")
    o = $col["bt1_status"]
    if (o != "not_observed" && o != "confirmed" && o != "censored_pre_failure" && o != "unknown") {
        printf "trial-sco-table: unrecognised bt1_status \"%s\" on line %d\n", o, NR > "/dev/stderr"
        print  "  Refusing to report rather than counting it as a survival." > "/dev/stderr"
        abort = 1; exit 1
    }
    # "recovered" counts as a FAILURE here: BT-1 occurred and the watchdog
    # rescued it. Counting it as a survival would understate the incidence of
    # the bug by exactly the watchdog success rate.
    # Censored rows cannot be classified as hung or survived — the early
    # intervention removed the outcome — so they are excluded from the 2x2
    # rather than being assigned to whichever cell looks harmless.
    # A trial whose treatment changed mid-run is excluded here too. The
    # cross-tab asks whether the stimulus coincided with a failure, and a
    # reconfiguration during the trial is itself a candidate cause — reinstalling
    # reloads btusb, restarting the watchdog resets state. Co-occurrence inside
    # a trial that was two experiments cannot be attributed to the stimulus.
    # CHANGED: endpoints differ; PERTURBED: something acted on the controller
    # between matching endpoints. trial-summary.awk excludes BOTH; excluding
    # only CHANGED here let an interior-perturbed trial into this 2x2 while
    # the rate table alongside it refused the same row.
    # Three exclusions, three counters. They used to share one counter and
    # one message — "censored by early watchdog intervention" — which is true
    # of only the first. A drifted treatment is a reconfiguration, not a
    # watchdog action; an unknown is an unreadable journal, not an
    # intervention. A reader tallying "how often did the watchdog censor a
    # window" against that line would count events that never happened
    # (review 2026-08-15T1752Z §3.3).
    # Same read-time correction as trial-summary (trial-reclass.awk, loaded
    # with -f before this file): a pre-fix CHANGED: marker that records only
    # a visibility loss re-enters the 2x2; real drift is still excluded.
    if (reclass_treatment($col["treatment"]) ~ /^(CHANGED|PERTURBED):/) { drifted++; next }
    if (o == "censored_pre_failure") { censored++; next }
    if (o == "unknown")              { unread++;   next }
    # "hung" here means the DEFECT occurred, regardless of whether the
    # controller was later rescued. Recovery is a fact about the mitigation,
    # not about whether the stimulus coincided with a failure.
    f = (o == "confirmed")
    if (s == "?" ) { unknown++; next }
    if (s+0 > 0) { if (f) a++; else b++ } else { if (f) c++; else d++ }
}
END {
    # awk runs END even after `exit` from another rule, so a refusal would
    # still print the table it is refusing to justify — the caller would see
    # a plausible report AND a non-zero status, and the report is what gets
    # read. Bail before printing anything.
    if (abort) exit 1
    printf "  %-22s %8s %12s\n", "", "hung", "survived"
    printf "  %-22s %8d %12d\n", "SCO setup requested", a+0, b+0
    printf "  %-22s %8d %12d\n", "no SCO setup", c+0, d+0
    if (unknown) printf "\n  (%d trial(s) with no SCO field — recorded before this was tracked)\n", unknown
    if (censored) printf "  (%d trial(s) censored by early watchdog intervention — excluded)\n", censored
    if (drifted)  printf "  (%d trial(s) whose treatment CHANGED or was PERTURBED mid-run — excluded)\n", drifted
    if (unread)   printf "  (%d trial(s) with UNKNOWN evidence — journal unreadable at close — excluded)\n", unread
    if (reclassified) printf "  (%d pre-fix CHANGED row(s) reclassified at read time — see trial-reclass.awk)\n", reclassified
    print ""
    # Braces are mandatory here. Written without them, the second and third
    # print statements fell OUTSIDE the if, leaving `else` with no matching
    # `if` — an awk syntax error that killed this entire block. It failed on
    # stderr while the surrounding shell reported success, so the cross-tab
    # never ran at all from the day it was written. The separately reported
    # defect — outcome read by field position — was real, but in code that
    # was never reached.
    if ((a+b) == 0) {
        print "  No trial has yet applied the stimulus. Until one does, nothing here"
        print "  distinguishes a build that fixes the bug from a run that never"
        print "  provoked it."
    } else if ((c+d) == 0) {
        print "  Every trial provoked SCO setup. The bottom row is empty, so this"
        print "  cannot yet separate the stimulus from the passage of time."
    } else if (b+0 > 0 && a+0 > 0) {
        print "  SCO setup has been survived AND followed by failure. The request"
        print "  alone is therefore not sufficient — look at its parameters."
    }
}
