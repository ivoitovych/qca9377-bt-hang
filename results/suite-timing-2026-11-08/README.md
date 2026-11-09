# Suite timing, 2026-11-08: each run alone on the machine

What it is: the first measurement for the question "why does a merge cycle take about 25
minutes, and what can be made faster without losing any check". Taken by the test-suite
maintainer on `c5defd7` (the ready line's candidate, `main` merged through `1fdcbd9`), in the
development container: 4 cores, nothing else running. The analysis and the proposals follow
in a note of their own; this directory keeps the raw figures.

## Wall time of each run (`scripts/suite-timing.sh`)

| run | seconds | note |
|---|---|---|
| `tests/run-tests` (parallel, 4 workers) | 57.1 | |
| `tests/run-tests --serial` | 134.4 | |
| `devtools/coverage --quiet --min 80` | 55.5 | |
| `devtools/test-comprehension --min 75` | 58.9 | runs its own traced suite (it can take `--dump` from coverage instead) |
| `devtools/awk-coverage --min 95` | 100.8 | its suite run takes as long as the others: the extra ~45 s comes after it (3147 profiles read) |
| `devtools/py-coverage --min 80` | 55.2 | |
| `devtools/journal-contract` | 0.8 | |
| `devtools/repo-scan . --all` | 12.0 | red here only because of the measurement's own scratch line (a path that reads as a UUID); not a finding |
| `devtools/mutate --self-test` | 0.5 | |
| `devtools/sandbox` | 1.0 | could not build its decoy world from a checkout under `/tmp`; not measured |
| `devtools/access-audit` | — | not measured here yet; CI took 12:00 for its traced suite step at `c5defd7` (run 42408323942), against about 3 minutes for all of `checks.yml` |

## Every unit's time (`unit-times/`)

One file per run that is parallel: each line is a unit's time in tenths of a second, the
section's length in lines, and its heading. They came from a one-line addition to the
runner's parent in a scratch clone, never committed, which printed the `_took` array it
already keeps (`tests/run-tests`, after the line that names the three longest units):

```bash
for _u in "${!_took[@]}"; do
    read -r _a _b _h <<<"${_secs[${_units[$_u]%% *}]}"
    printf '%d\t%d\t%s\n' "${_took[$_u]}" "$(( _b - _a ))" "$_h"
done >> "$UNIT_TIMES"
```

What they show, alike in every run: 46 units summing to about 190 to 200 s, so 4 cores give
about 50 s and the run is bound by the total, not by its longest unit. The longest are the
checkout world's two sections (held, save: 23 to 27 s each, each one `repo-save` validating
and scanning the whole checkout inside the world), then the publish gates over scratch
repositories and `bt-trace`'s supervision loop (10 to 12 s each). On 16 cores the two checkout
world sections would be the floor.
