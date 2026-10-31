#!/bin/sh
# List every sanitizer summary line in the runs' pytest logs, per file.
# Usage: find-sanitizer.sh
cd /root/exp/agent-work/co03/runs || exit 1
grep -HE "SUMMARY: (AddressSanitizer|UndefinedBehaviorSanitizer|LeakSanitizer)|runtime error:" */pytest.log | cut -c1-260
