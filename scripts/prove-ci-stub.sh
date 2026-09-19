#!/bin/bash
# The two new devtools/ci invariants, run standalone with the same gh stub the
# suite uses, so they can be checked here while a trial keeps the suite closed.
set -uo pipefail
REPO=/root/exp/qca9377-bt-hang
P=0; F=0
ok()  { printf '  PASS  %s\n' "$1"; P=$((P+1)); }
bad() { printf '  FAIL  %s\n' "$1"; F=$((F+1)); }
CIS=$(mktemp -d); mkdir -p "$CIS/bin" "$CIS/elsewhere"
cat > "$CIS/bin/gh" <<'EOF'
#!/bin/bash
echo "$PWD" >> "${CI_STUB_LOG:?}"
[[ -n "${CI_STUB_FAIL:-}" ]] && { echo "failed to determine base repo: not a git repository" >&2; exit 1; }
case "$*" in
  *"run list"*) printf 'success\tcompleted\t123\tstub run\n' ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$CIS/bin/gh"; : > "$CIS/calls"
OUT=$(cd "$CIS/elsewhere" && env PATH="$CIS/bin:$PATH" CI_STUB_LOG="$CIS/calls" "$REPO/devtools/ci" HEAD 2>&1); rc=$?
seen=$(sort -u "$CIS/calls" | head -1)
[[ "$seen" == "$(cd "$REPO" && pwd -P)" ]] && ok "gh ran with the checkout as cwd (rc=$rc): $OUT" || bad "gh ran from '$seen' (rc=$rc): $OUT"
FAIL=$(cd "$CIS/elsewhere" && env PATH="$CIS/bin:$PATH" CI_STUB_LOG="$CIS/calls" CI_STUB_FAIL=1 BT_CI_GRACE=2 BT_CI_POLL=0 "$REPO/devtools/ci" --wait HEAD 2>&1); frc=$?
(( frc == 2 )) && [[ "$FAIL" == *"gh run list failed"* && "$FAIL" == *"not a git repository"* && "$FAIL" != *"grace budget"* ]] \
    && ok "gh failure stops the tool with gh's message (rc=$frc)" || bad "gh failure misread (rc=$frc): $FAIL"
rm -rf "$CIS"
printf '\n  %s passed, %s failed\n' "$P" "$F"; (( F == 0 ))
