# actions-render.awk — collapse/cadence renderer for bt-actions. Loaded as
#
#   sort -k1,1 stream | awk -v raw=<0|1> -f tools/lib/timestamp.awk -f tools/lib/actions-render.awk
#
# Input records: "<iso-timestamp>\t<CLASS>\t<label>".
#
# Extracted from an inline program in tools/bt-actions that carried a private
# days()/tosec() copy of the civil-date arithmetic — the third such copy
# beside the shared library whose header says "one implementation" (review
# 2026-08-15T1752Z §3.1; HC-07 in the reviews register). iso_secs() also
# brings its guards: an unparseable timestamp yields -1 rather than a
# plausible number.
#
# The fractional part of these timestamps is MICROseconds (journalctl prints
# six digits); iso_secs() carries it as a fraction of a second, so a cadence
# printed here cannot repeat the 1000x inflation this renderer once had.

function disp(t,   d, s) { split(t, d, "T"); s = d[2]; sub(/[+-][0-9:]+$/, "", s); return substr(s, 1, 12) }
function flush(   span, cad) {
    if (n == 0) return
    if (n == 1) {
        printf "%-13s %-5s  %s\n", disp(ft), fc, fl
    } else {
        span = iso_secs(lt) - iso_secs(ft)
        cad = span / (n - 1)
        if (cad >= 1)
            printf "%-13s %-5s  %s\n                          x%d until %s, every ~%.1fs\n", disp(ft), fc, fl, n, disp(lt), cad
        else
            printf "%-13s %-5s  %s\n                          x%d until %s (burst, %.2fs apart)\n", disp(ft), fc, fl, n, disp(lt), cad
    }
    n = 0
}
{
    ts = $1; cls = $2
    lbl = $0; sub(/^[^\t]*\t[^\t]*\t/, "", lbl)
    if (raw == 1) { printf "%-13s %-5s  %s\n", disp(ts), cls, lbl; next }
    if (lbl == fl && cls == fc) { n++; lt = ts; next }
    flush()
    ft = ts; lt = ts; fc = cls; fl = lbl; n = 1
}
END { flush() }
