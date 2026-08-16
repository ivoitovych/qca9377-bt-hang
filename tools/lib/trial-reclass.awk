# trial-reclass.awk — read-time correction for one known writer defect.
#
# Load with -f BEFORE a consumer of results.tsv, exactly as bt-trial's report
# does; the fixtures load it through a DEPS file. It defines a function and
# owns one global (`reclassified`); it has no rules, so it changes nothing
# about how the consumer reads its input.
#
# WHAT IT CORRECTS. Before 2026-08-15, bt-trial's closer compared the two
# treatment fingerprints byte for byte, so a field that became UNREADABLE at
# close — the radio left the bus and power/control could no longer be read —
# was recorded as a treatment CHANGE:
#
#   CHANGED:...,power=auto,...->...,power=?,...
#
# The writer has since been fixed (treatment_only_became_unreadable() in
# tools/bt-trial): losing sight of a value is not evidence that the value
# changed, and for BT-1 it is the expected consequence of the failure itself.
# But the fix corrected the CLASSIFIER, not the RECORD. Row 2 of the real
# results.tsv — trial stock #2, one of the two most informative failures in
# the observational record — still carries the CHANGED: marker, pools with
# nothing, and is excluded from every rate (review 2026-08-15T1752Z §7).
#
# The repo's no-hand-editing rule for evidence is right, so the row is not
# rewritten. Instead every reader applies the SAME correction the writer now
# applies, at read time, and says it did:
#
#   * a CHANGED:a->b treatment where b differs from a ONLY by fields whose
#     closing value is `?` is reclassified to `a` — the treatment the trial
#     verifiably ran under;
#   * any other difference (a real value at both ends, a key mismatch, a
#     malformed marker) is left exactly as recorded — this function must
#     never launder a genuine mid-trial change back into a denominator;
#   * the consumer prints a note when `reclassified` is non-zero, so a
#     reader tallying the report against the raw TSV sees why they differ.
#
# PERTURBED: rows are NOT touched: an interior perturbation is real evidence
# of an action on the controller, not a visibility loss.

function reclass_treatment(t,    body, p, a, b, n, m, fa, fb, i, ka, kb, vb) {
    if (t !~ /^CHANGED:/) return t
    body = substr(t, 9)                    # strip "CHANGED:"
    p = index(body, "->")
    if (p == 0) return t                   # malformed marker: leave as recorded
    a = substr(body, 1, p - 1)
    b = substr(body, p + 2)
    n = split(a, fa, ",")
    m = split(b, fb, ",")
    if (n != m) return t
    for (i = 1; i <= n; i++) {
        if (fa[i] == fb[i]) continue
        ka = fa[i]; sub(/=.*/, "", ka)
        kb = fb[i]; sub(/=.*/, "", kb)
        vb = fb[i]; sub(/^[^=]*=/, "", vb)
        # Same key, and the closing value is `?` — unreadable, not changed.
        # Anything else is a real difference and the row stays CHANGED.
        if (ka != kb || vb != "?") return t
    }
    reclassified++
    return a
}
