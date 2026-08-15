# EX-022 — warm-reboot-from-collapse-prevents-boot

**Claim.** After the controller reached full USB collapse, a warm reboot did not merely fail to recover Bluetooth — the machine failed to boot. Linux shut down cleanly at 21:44:11; the next boot begins 245 s later, with no journal entry in between, and only after a 10-second power-button hold and a power-on.

**Relevance.** The absence of a journal is the evidence: the machine never reached journald, so the hang was in firmware/POST or very early kernel. This is the strongest instance yet of the untested M.2-rail claim, and it extends the fault's consequence beyond Bluetooth to the host's ability to boot.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl --list-boots --no-pager | tail -3; echo '--- last lines of the boot that was told to reboot ---'; journalctl -b -1 -n 3 --no-pager -o short-iso
```

## Output

Verbatim, 7 line(s), exit status 0.

```
 -2 54b5b30651db40f5b030b1bef6d0e719 Fri 2026-08-14 13:04:52 CEST Fri 2026-08-14 18:21:07 CEST
 -1 9d973714a0ce42549b74cc502f65eea4 Fri 2026-08-14 18:21:39 CEST Fri 2026-08-14 21:44:11 CEST
  0 0343c15ddcd24c3b9f0605d678c256e0 Fri 2026-08-14 21:48:16 CEST Fri 2026-08-14 21:53:41 CEST
--- last lines of the boot that was told to reboot ---
2026-08-14T21:44:11+02:00 n systemd-journald[458]: Received SIGTERM from PID 1 (systemd-shutdow).
2026-08-14T21:44:11+02:00 n dnsmasq[2549]: exiting on receipt of SIGTERM
2026-08-14T21:44:11+02:00 n systemd-journald[458]: Journal stopped
```

## Sequence

**Two kinds of line below, and they are not equally strong.** Rows marked *log* are in the
journal or in `wtmp`. Rows marked *operator* are the operator's account and have **no
supporting record** — the section after this says what was searched for and not found.

| time | source | event |
|---|---|---|
| 21:03:35 | log | USB collapse begins (`EX-021`) — device leaves the bus |
| 21:44:11 | log | `Reached target reboot`; `Syncing filesystems`; `Journal stopped` |
| — | log | **245 s with no journal entry**, corroborated independently by `wtmp`: `shutdown system down … 21:44 - 21:48 (00:04)` |
| — | **operator** | repeated boot attempts, black screen |
| — | **operator** | 10-second power-button hold → power off → power on |
| 21:48:16 | log | boot `0343c15d` begins normally; `13d3:3503` enumerates |

## Reading

**What the logs establish.** Boot `-1` shut down in the ordinary way, so Linux completed
its side cleanly. The next journal entry is 245 s later in a different boot, and `wtmp` —
a separate file written by a separate mechanism — records the same 4-minute down period.
Restarts on this machine otherwise take 22–34 s.

**What the logs do NOT establish, and what was checked.** `/sys/fs/pstore` is **empty**:
no firmware or kernel crash record exists. So there is no evidence of a POST hang *as
such*. The 245 s silence is equally consistent with:

* a firmware/POST hang, as the operator describes;
* early-kernel boot attempts that failed before journald;
* the machine sitting powered off for four minutes.

**Nothing in any log distinguishes these.** The operator's account selects the first; the
data selects none of them. An earlier draft of this exhibit asserted the hang "was in
firmware/POST or very early kernel, before journald exists" — that was the operator's
account restated as a finding, and it is withdrawn.

The 245 s gap is real, corroborated, and anomalous. What happened inside it is unrecorded.

**What it adds to the M.2-rail question.** The claim asserted in the protocol,
`docs/bug-report.md` and `docs/fix-proposal.md` is that a warm reboot does not drop the
rail and will not recover the controller. This is the strongest instance yet, and it is
stronger than the claim: from the collapsed state a warm reboot did not produce a running
machine at all. The consequence of the fault is not confined to Bluetooth.

**Stated narrowly.** `n = 1`. No log exists from the failed attempts — by construction.
Nothing here proves the QCA9377 caused the boot failure; what is established is the
sequence, the clean shutdown, the 245 s silence and the recovery by power cycle. A second
instance would need the same precondition: warm-reboot deliberately from a post-collapse
state.

## The instrument mislabels this boot, and the gap column is why

`bt-boot-provenance` prints:

```
0  2026-08-14 21:48:16  245s  reboot  4.027s  yes  <- recovered across a reboot target
```

**That flag is wrong here.** The OS reached `reboot.target`, so `prev end` reads `reboot`
— but the machine did not boot from that reboot. It was power-cycled by hand, which the
journal cannot witness, exactly as the tool's own footer warns.

The **245 s gap** carries the signal the shutdown-target column cannot: it is 7–10× the
normal 22–34 s. This is the third time the OS-trajectory-versus-electrical-state ambiguity
has produced a misleading line (`EX-017`, `EX-019`, here), and it is the first time the
ambiguity has been resolvable from data already in the table.

**Refinement for `BL-01`:** when the inter-boot gap falls far outside the normal range,
withhold the "recovered across a reboot target" claim rather than print it. A gap that
long is evidence the reboot did not complete on its own terms.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-14T21:53:43+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `0343c15d` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
