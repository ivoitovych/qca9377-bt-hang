# The isolation itself, now measured by an exact trace, and what changed in shipped tools

**From:** test suite maintainer · **To:** main branch maintainer · **Branch:** `tests/unit-testing-introduction`

A follow-up to this morning's summary (`2026-10-09T0355Z`). Two commits since,
both on the branch you would merge.

## 1. What was found

The decoy world catches a machine *answer*. It cannot see an access that
answers nothing: an existence check of a path that is absent here, or a read of
a file that is missing in CI and present on the laptop. Such a test passes
everywhere except on the investigation machine. One run of the suite under
`strace` found nine kinds:
- jq's `~/.jq`, git's `~/.config/git/*` and `/etc/gitattributes`, and Python's
  user site-packages;
- the real `/run/bt-trial/current`, read by repo-save's tests;
- the real `/var/log/bt-health/trace` and its `gaps.log`, read by `bt-status`
  and `bt-incident`;
- the real `/etc`, `/usr/local` and `/var/log`, read by `uninstall.sh`'s dry run
  and by `verify-restored.sh`;
- `/tmp` outside the run, written by `bt-verify-kernel-mechanism`.

All are closed. The run now has its own home, its own trial state and a
declared health directory, and every seam whose default is on the machine is
declared for the whole run.

## 2. Shipped tools that changed

Defaults are unchanged when the variables are unset, except where noted.

| file | change |
|---|---|
| `tools/bt-incident` | reads `BT_TRACE_DIR`; the trace directory used to be written in |
| `bin/bt-capture`, `bin/bt-evidence`, `bin/bt-trace`, `bin/bt-usbmon`, `tools/bt-actions`, `tools/bt-capdiff`, `tools/bt-sco`, `tools/bt-status`, `tools/bt-trial` | the trace, capture and usbmon defaults are `${BT_HEALTH_DIR:-/var/log/bt-health}/…`, so setting `BT_HEALTH_DIR` moves all four |
| `tools/verify-restored.sh` | takes `BT_DESTDIR`, the staging prefix `install.sh` and `uninstall.sh` already take, and checks every artifact under it; its health directory defaults under it |
| `tools/bt-verify-kernel-mechanism` | its temporary copy and `.hex` go under `TMPDIR`, and both are removed on every exit path |
| `tools/bt-boot-stats` | **runs the `bt-boot-list` beside it first**, then the one in `/usr/local/bin`: the order `bt-phase` has had since 2026-09-29. Installed, they are the same file. From a checkout, it no longer runs whatever was last deployed. |

## 3. New

- **`devtools/access-audit`** runs the suite, or `-- <cmd>`, under `strace` and
  fails on any machine access that `tests/access-allowlist` does not name with a
  reason. An allow line that nothing matched also fails it.
  - `--self-test` plants each kind of access, and each must be caught.
  - The classifier is `devtools/access-classify`.
  - CI runs the audit as a separate job, in parallel with the main checks.
  - It needs `strace`, which both CI jobs now install.
  - Run under the decoy world, it reports the self-test as not asked:
    `devtools/sandbox` now sets `BT_DECOY_WORLD` for its command.
- **`tests/system-resources.md`**, the catalog of every machine resource the
  code touches and what isolates it in tests. An invariant derives its seam list
  from the code, so a new `${BT_X:-/machine/path}` without a line there fails
  the suite. Its §6 lists the `scripts/` that change the machine by design; the
  suite never runs them. Its §7 lists what is still open: the inherited PATH,
  host tool presence and the clock.
- **`sudo`, `runuser` and `gh`** are on the tripwire (`tests/machine-tools`).
  No test reached any of them.
