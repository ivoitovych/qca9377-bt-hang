# Verification of the noble SRU for the two systemd commits (99e6f682d3, 51b2bcf835)

Compared throughout: stock `255.4-1ubuntu8.19` (downloaded from noble-proposed; 8.18 was not needed) against the 8.20 test
packages (8.19 plus the two commits). Hashes of both package sets: `scripts/PACKAGES.txt`. Every comparison checks each
journalctl's exit status, requires non-empty output where output is expected, and compares sha256 (or line/byte counts where
stated). Each item has its own README with method, exact commands, termination conditions, tables, raw TSVs and scripts.

## Findings, most important first

1. **No stock/patched difference was found in any correctness test.**
   * 4A frozen copies (4 fixtures, 36 comparisons incl. 12 archived files of a real journal): identical sha256 everywhere.
   * 4C booted noble guest with journald writing and rotating, a `journalctl -f` and a later full read, system and user-session
     streams, 2 x 24000 numbered messages per phase: no omission, duplicate or reorder in either build; `--verify` passed
     38 of 38 and 76 of 76 files; final static journal identical.
   * 4D journals in the old format (systemd 249, no `tail_entry_offset`) and a mixed set: identical; the fallback branch was
     observed (header_size 256) under a debugger.
   * 4E imported/merged journals (header machine ID against entry machine ID, five fixtures, 45 comparisons): identical.
2. **Removal of archived files under an open reader (4B): no difference, but both builds share weak spots.** The one case that
   looked worse for the patched build in a first pass (API reader, truncated current file: stock 0 of 6 failures, patched 3
   of 6) was timing luck: 17 of 56 against 21 of 56 runs, p = 0.55. After about 1400 runs no cell differs at p < 0.05. Both
   builds: `journalctl` exits 1 with `Failed to iterate through journal: Bad message` when a file ahead of the reader is
   truncated or hole-punched (the case upstream 101b8633c2 addresses; not in either build), and an sd-journal API program
   without a SIGBUS handler dies with SIGBUS when a mapped file is truncated (the library does not install the handler;
   `journalctl` and journald do). Plain `unlink` is harmless in both.
3. **A shared ordering defect (4E):** with several entry machine IDs behind one header machine ID (the shape journal-remote
   produces), output is not in true time order in stock; the patched build reproduces it exactly. The two commits neither
   cause nor fix it (upstream ae940730c6 was deliberately not added).
4. **Performance on the host (4F), run to completion, no caps hit:** `-b all` at 100 files 907.8 s (mixed) and 1098.3 s
   (system) stock against 83.8 s and 93.1 s patched (10.8x, 11.8x); apport's `-b -a --system` 23.6 s against 2.9 s (mixed-100);
   sos's first 100 MB of `--reverse` 220 s against 19.6 s. Structural: stock makes 540 to 560 fstat-family calls per printed
   line at 100 files (16.8 million for 30000 lines), the patched build a constant 355.
5. **File counts at defaults (4G):** defaults hold a journal directory to about 100 files in total (active and archived,
   system and user together); a lived-in single-user desktop plausibly sits at 10 to 40 and reaches 50 to 100 through many
   small files (unclean shutdowns, monthly rotation, hash-table rotation, other users). The test laptop's 492 files come from
   a non-default configuration. The slowdown is already visible below 20 files in a public report.

## NOT DONE

Nothing in the brief was skipped. Limits: 4B used a synthetic fixture of 16 files; the stock stack of the API-reader crash was
not symbolised (stock debug symbols were not fetched); 4C is one guest and two streams; 4F is one run per query and build
(the one suspicious value, `--list-boots`, was repeated ten times and was noise).

## Downloads

| item | source | size | sha256 |
|---|---|---|---|
| `noble-server-cloudimg-amd64.img` | https://cloud-images.ubuntu.com/noble/current/ (checked against that directory's `SHA256SUMS`: OK) | 621284352 bytes | `04e8f2461a16a44e78a370284471f29616cdd9baf1893df25807b71f985b6c94` |
| stock 8.19 `systemd`, `libsystemd0`, `libsystemd-shared`, `systemd-journal-remote` (noble-proposed) | the Ubuntu archive | see `scripts/PACKAGES.txt` | listed there |
| 22.04 `systemd-journal-remote` 249.11-0ubuntu3.23 (installed inside a container to write the old-format files) | the Ubuntu archive | package manager | not recorded |
| container images `ubuntu:24.04`, `ubuntu:22.04` | Docker Hub | | |
| a few public mailing-list pages (read only, saved as text in the work directory) | lists.freedesktop.org | | |

## Scratch created (work directory, not in the repository)

`verify/data/4A` (synthetic copies; the 12 copies of the laptop's archived files, `real12`, were deleted at the end: names,
sizes and the deletion listing are in `4A-frozen-dataset-equivalence/FIXTURE-SHA256.txt` and `scripts/cleanup-4A-record.txt`),
`verify/data/4B`, `4D`, `4E`, `4F` (about 14 GB of synthetic copies), `verify/vm` (cloud image, working copy, ISOs, console
logs, raw guest outputs), `verify/results`, `pkgx` (unpacked stock and test packages and their debug symbols), the
`co46-verify:1` image. Nothing was installed on the host; no host journal, settings or Bluetooth state was touched.

## Items

`4A-frozen-dataset-equivalence`, `4B-archived-files-under-open-reader`, `4C-booted-noble-vm`, `4D-old-journal-format`,
`4E-imported-merged-journals`, `4F-host-headline-numbers`, `4G-file-counts-at-defaults`, `scripts` (shared tooling).

## Note on committed text

In the committed copies of file listings (`FIXTURE-SHA256.txt`, `verify-*.txt`, `4D-gen.txt`) the `@` of journal file names (between `system` and
the file number) is written `-`, and in a few scripts a glob `[@]` stands for it, so that the repository scan does not
mistake the names for addresses; the data and logic are otherwise as run. Work-area paths are written `<work dir>`.
