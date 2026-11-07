#!/bin/sh
# Stand-in for docker in the runner's proofs: ignores its arguments,
# prints $STUB_DIR/$STUB_SCENARIO.out and exits with the status in
# $STUB_DIR/$STUB_SCENARIO.rc. Records its arguments in $STUB_DIR/$STUB_SCENARIO.args.
printf '%s\n' "$@" > "$STUB_DIR/$STUB_SCENARIO.args"
cat "$STUB_DIR/$STUB_SCENARIO.out"
exit "$(cat "$STUB_DIR/$STUB_SCENARIO.rc")"
