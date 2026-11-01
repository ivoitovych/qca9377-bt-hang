#!/bin/bash
# Every per-test total of this campaign, into results/totals.txt.
W=/root/exp/agent-work/co23-co37-review-20261101
P=$W/scripts/per-test.py
R=$W/runs
mkdir -p $W/results
{
	$P --totals $R/co23-before co23 final
	$P --totals $R/co23-after co23 final final2 control pause orig
	$P --totals $R/stk-base pair a2dpfile fpair fa2dp
	$P --totals $R/stk-fix12 pair a2dpfile fpair fa2dp
	$P --totals $R/stk-base adj
	$P --totals $R/stk-fix1 adj
	$P --totals $R/stk-fix12 adj
	$P --totals $R/stk-base adj2
	$P --totals $R/stk-fix1 adj2
	$P --totals $R/stk-fix12 adj2 adj2probe
	$P --totals $R/rfc co37
	$P --totals $R/rfc-co37 co37
	$P --totals $R/ext-v572 adj2probe rel
	$P --totals $R/prop3 adj2
	$P --totals $R/prop4 adj2 adj fa2dp
} > $W/results/totals.txt 2>&1
cat $W/results/totals.txt
