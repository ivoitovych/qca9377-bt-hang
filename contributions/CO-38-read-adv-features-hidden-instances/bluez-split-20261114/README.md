# CO-38: the BlueZ test split, after the 2026-11-14 outside review

Four of five reviewers asked for this (`../../../reviews/2026-11-14T1400Z-kernel-patches-review-answers-checks.md`
§4): the old `[PATCH BlueZ 0/3]` installed duration cases that fail until CO-12, which is not
posted.

- **`series-a/`** holds one BlueZ patch on master `20ffd285b58f`: the helpers, plus the case "Add
  Ext Advertising - Instance 2 listed alone". It builds without warnings.
  - The helpers still carry the `ext_params` and `replace_ms` paths, which this case does not use.
    Whether to strip them is the operator's choice.
- **`series-b-held/`** holds the fourteen duration cases and the mesh-tester case, on top of
  series A. They wait for CO-12. With both series applied, the tree is identical to the old
  three-patch series.

| mgmt-tester `-p Add`, 114 cases, 3 runs each | result |
|---|---|
| bluetooth-next `da3cc02587c6` | 113 of 114 every run; the failure is "Instance 2 listed alone" |
| `da3cc02587c6` + CO-38 | 114 of 114 every run |

- **The bot's checks** (`scripts/bot-ci-local.sh --space user`) on series A: exit 0, with no
  difference between base and patched. CheckPatch and GitLint pass.
- **Checked on copy:** the six totals (`logs/mgmt-tester-add-totals.txt`, taken from the raw logs)
  and the bot summary and reports.
- **Left in the work area:** the raw tester logs, which print emulated addresses, and the bot's
  per-check logs.
- **Changed on copy:** nothing.
