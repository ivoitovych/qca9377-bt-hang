# interval.awk — print the interval in seconds between two ISO timestamps.
#
#   awk -f tools/lib/timestamp.awk -f tools/lib/interval.awk -v a=<start> -v b=<end>
#
# KEPT IN A FILE FOR THE SAME REASON AS capdiff-match.awk. `awk -f lib.awk
# 'BEGIN{...}'` does not run the BEGIN block: once -f is given, awk takes the
# program only from the -f files and treats the positional string as an input
# filename. The BEGIN block is silently ignored, awk blocks trying to read a file
# named "BEGIN{...}", and the caller records an empty interval.
#
# Prints nothing and exits non-zero if either timestamp is unparseable, so a
# caller cannot mistake a parse failure for a zero-length interval.

BEGIN {
    sa = iso_secs(a)
    sb = iso_secs(b)
    if (sa < 0 || sb < 0) exit 1
    printf "%.3f", sb - sa
}
