# External data cache — fetch once, verify, record what it is

**The problem this solves.** Source investigation needs material that is not in this
repository: kernel sources, `btusb.c` at old tags, package indices, debug symbols, ddebs.
Fetching it repeatedly is slow, and worse, **it is not equally available to everyone working
on this project**. Two concrete cases:

- `debuginfod.ubuntu.com` times out from the investigation machine at 20 s and returns an
  explicit policy denial from the test-suite maintainer's environment, while
  `archive.ubuntu.com` answers from both in under a second.
- `launchpad.net` answers from the investigation machine in **0.24 s** and is **blocked**
  from the test-suite maintainer's — which matters because Launchpad is the only place that
  keeps **superseded** source packages, and the kernel this investigation started on is
  superseded.

So "can you fetch X" has a different answer depending on who is asked, and the answer
changes over time. A cache turns that into a fact about a file rather than a fact about
someone's network.

**And it protects re-derivation.** Upstream moves. `-28` has already fallen out of
`archive.ubuntu.com`; `bluez-dbgsym` for `5.72-0ubuntu5.5` was never published for amd64 at
all. A finding that cites a file nobody can fetch again is in the same position as `EX-001`
through `EX-008`, whose journals rotated away.

## Where it lives, and why not in the repository

```
/var/cache/bt-investigation/<topic>/
```

**Outside the tree, deliberately.** These are third-party artefacts, often tens or hundreds
of megabytes, and this repository is public and small on purpose. The rule is the same one
`bt-archive` and `bt-snapshot` enforce for raw journals: **the artefact stays outside, a
manifest goes in.**

What is committed is `docs/external-cache-manifest.tsv` — what was fetched, from where, its
size and its SHA-256. Anyone can re-fetch and verify, or ask a colleague to.

## Rules

1. **Verify on arrival, against the publisher's own checksum where one exists.** A Debian
   source package ships `Checksums-Sha256` in its `.dsc`; check the file against it, not
   against itself. Record the result.
2. **Record the URL and the date.** A URL that worked once and 404s later is still evidence
   of where the thing came from.
3. **Never cache anything unsanitised from this machine.** The cache is for *external*
   material. Journals, captures and coredumps go to `bt-archive` / `bt-snapshot`
   destinations, which have their own no-commit guards.
4. **Say which build a source reading came from.** The investigation machine has run
   `7.0.0-28`, `-29` and `-30` during this project. A line number is meaningless without the
   version it was read in.

## Current contents

| topic | what | why it could not simply be re-fetched |
|---|---|---|
| `kernel-source/` | `linux-hwe-7.0 7.0.0-28.28~24.04.1` `.dsc` + `.diff.gz` — the **Ubuntu delta**, which patches `hci_qca.c`, `hci_sync.c`, `hci_event.c`, `hci_conn.c`, `btusb.c` and `sco.c` | `-28` is superseded and gone from `archive.ubuntu.com`. Only Launchpad keeps it, and Launchpad is blocked from the test-suite maintainer's environment |

⚠️ The `.orig.tar.gz` is **not** cached — it is the mainline tarball, unchanged across these
revisions and available from `archive.ubuntu.com` to everyone. The delta is the part that is
both scarce and load-bearing: reading mainline and calling it "what we run" is the error the
external-review brief's first ground rule exists to prevent.

## Which kernel ran when — needed to read any line number correctly

| boots | dates | kernel |
|---|---|---|
| `-15` … `-4` | 2026-08-13 → 2026-08-17 | `7.0.0-28-generic` |
| `-3`, `-2` | 2026-08-19, 2026-08-21 | `7.0.0-29-generic` |
| `-1`, `0` | 2026-08-22 → | `7.0.0-30-generic` |

Re-derivable with:

```console
$ journalctl -k -b <idx> --no-pager -o cat | grep -m1 -oE 'Linux version [0-9.]+-[0-9]+-generic'
```

**This table is why the cache exists.** Exhibits `EX-030`–`EX-032` were captured under
`-28`; `EX-033` under `-29`; `EX-034` spans `-29` → `-30`. Five exhibits recorded
`7.0.0-28-generic` regardless, because they were hand-written and the value was copied
forward. Two are corrected; the others were right by coincidence of date.
