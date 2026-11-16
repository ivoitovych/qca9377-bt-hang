#!/bin/bash
# Performance-related lines in the SRU changelog ranges, with their version.
W=$WORKDIR/pkg
scan() {   # file startpattern endpattern
    awk -v s="$2" -v e="$3" '
        $0 ~ /^systemd \(/ { cur = $0; inrange = 0; if ($0 ~ s) started = 1; if ($0 ~ e) exit }
        started { inrange = 1 }
        inrange && tolower($0) ~ /perform|slow|speed|fast|optimi|latency|cpu usage|high cpu|busy loop|quadratic|scal/ { print cur "\n    " $0 }
    ' "$1"
}
echo "=== jammy 249.11-0ubuntu3.x"
scan $W/precedent/jammy-249.11-0ubuntu3.12.changelog '249.11-0ubuntu3[.]' '249.11-0ubuntu3[)]'
echo
echo "=== noble 255.4-1ubuntu8.x (through 8.19)"
scan $W/x819/s/debian/changelog '255.4-1ubuntu8' '255.4-1ubuntu7'
