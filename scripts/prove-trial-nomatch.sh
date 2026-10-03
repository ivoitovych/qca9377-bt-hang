#!/bin/bash
# prove-trial-nomatch.sh — standalone proof of the suite's two no-match closer
# checks, for when the suite cannot run (trial open): a journalctl --grep read
# that matched nothing exits 1 with a silent stderr (systemd 255), and the closer
# must read that as a clean window — not_observed, counts 0, perturbed none —
# while exit 1 WITH a complaint on stderr is still an unreadable journal.
#
#   scripts/prove-trial-nomatch.sh
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
LC=$(mktemp -d)
ok()  { echo "  ✓ $*"; }
bad() { echo "  ✗ $*"; }
mkdir -p "$LC/bin" "$LC/sysfs/3-3/3-3:1.0/bluetooth/hci0" "$LC/sysfs/3-3/power"
for s in hciconfig bt-incident bt-state; do printf '#!/bin/sh\nexit 0\n' > "$LC/bin/$s"; chmod +x "$LC/bin/$s"; done
echo 13d3 > "$LC/sysfs/3-3/idVendor"; echo 3503 > "$LC/sysfs/3-3/idProduct"; echo on > "$LC/sysfs/3-3/power/control"

stub() {   # stub <what -k does>
    cat > "$LC/bin/journalctl" <<STUB
#!/bin/sh
for a in "\$@"; do
  case "\$a" in
    --help) echo '  -g --grep=PATTERN  Show entries with MESSAGE matching PATTERN'; exit 0 ;;
    -k) $1 ;;
  esac
done
exit 0
STUB
    chmod +x "$LC/bin/journalctl"
}
run() {   # run <verb> — every seam set, never the real tree
    PATH="$LC/bin:$PATH" BT_REPO="$LC" BT_EVIDENCE_REPO="$LC" BT_STATE="$LC/state" \
        BT_SYSFS_USB="$LC/sysfs" tools/bt-trial "$@"
}

stub 'exit 1'
run autostart stock >/dev/null 2>&1
OUT=$(run ok 2>&1); rc=$?
ROW=$(awk -F'\t' 'NR == 2 { print $8, $11, $13, $23 }' "$LC/evidence/trials/results.tsv" 2>/dev/null)
if [[ "$ROW" == "not_observed 0 0 none" ]]; then
    ok "a filtered read that matched nothing is a clean window, not an unreadable journal"
else
    bad "no-match close: rc=$rc row (bt1_status sco_sent timeouts perturbed)='$ROW'"
    echo "$OUT"
fi

stub 'echo "Failed to open journal: Input/output error" >&2; exit 1'
rm -rf "$LC/evidence" "$LC/state"
run autostart stock >/dev/null 2>&1
run ok >/dev/null 2>&1
ROW2=$(awk -F'\t' 'NR == 2 { print $8, $23 }' "$LC/evidence/trials/results.tsv" 2>/dev/null)
if [[ "$ROW2" == "unknown unknown" ]]; then
    ok "exit 1 with a complaint on stderr is still an unreadable journal -> unknown"
else
    bad "failed-read close: row (bt1_status perturbed)='$ROW2'"
fi
rm -rf "$LC"
