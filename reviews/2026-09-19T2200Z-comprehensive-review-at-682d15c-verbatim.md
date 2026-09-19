# Comprehensive review: qca9377-bt-hang

Reviewed project: **682d15c97bbd10019b81379a9e4e03127f6c47a1**. Remote `main` was checked again at the end of source investigation and had not moved. BlueZ comparison: **ebbb4ee31ad7011cead3d6394c68d10076ab55fc**. Linux comparison: **40288c9206c17eb66a603262e06a58d300d0f279**, plus v7.0 and the original fallback commit.

**Verdict:** the two BlueZ changes remain credible, narrowly scoped crash fixes. The controller investigation contains useful observations, but its current causal narrative is stronger than the evidence establishes, and its upstream baseline is stale in a consequential way. Several tools can still corrupt the interpretation, preservation, or publication status of evidence. These issues warrant changes before treating the repository as a reliable turnkey investigation package; they do not justify withdrawing the independent BlueZ fixes.

This is a source-and-evidence review with local execution, not a hardware reproduction. I inspected the current documentation, relevant exhibits and archived logs, both patches and their upstream call paths, capture and incident collection, installation/removal, trial lifecycle, diagnostic tools, tests, CI, and the existing review disposition. I ran the invariant suite and targeted isolated reproductions. I did not execute controller resets, install services, build a kernel, replay real Bluetooth hardware, inspect unavailable private captures/cores, or review every historical branch line by line. No repository changes or upstream messages were made.

## 1. Most consequential discovery: the missing upstream ID has already been added

**DR-01 — High priority; confirmed upstream-baseline problem.**

Linux commit [`dc16388d45ecbd3be0d8c9424dbbaa2c81806578`](https://github.com/torvalds/linux/commit/dc16388d45ecbd3be0d8c9424dbbaa2c81806578), “Bluetooth: btusb: Add IMC Networks QCA9377 to quirks table,” adds exactly:

```c
{ USB_DEVICE(0x13d3, 0x3503), .driver_info = BTUSB_QCA_ROME |
                                         BTUSB_WIDEBAND_SPEECH },
```

The author is Tibor Harcsa; the author timestamp is June 29, 2026, and committer timestamp August 7, 2026. I confirmed the entry in current Torvalds Linux and independently confirmed its absence in v7.0. Thus the project's observation about its older kernel is compatible with the source, while a present-tense claim that this ID remains absent upstream is obsolete.

The commit describes BLE scanning failures, not this project's demonstrated audio wedge. It also supplies descriptors for the same ID, including alt 1/9 bytes and alt 3/25 bytes. Its existence does **not** prove this hardware is now fixed. It does mean another reporter has already supplied the exact identity patch the project originally considered, and the QCA setup/firmware path must be brought back into the experiment design.

In the current driver, `BTUSB_QCA_ROME` selects `btusb_setup_qca` and the QCA reset callback; the WBS flag advertises support. That changes initialization as well as recovery. Late manual USB resets on a controller initialized through the old generic path do not evaluate the whole upstream change.

**Action:** retain the older-kernel finding with a version qualifier; link the accepted change prominently; determine whether the installed Ubuntu package contains it by source/binary provenance, not by its version string alone. Test a controlled build containing the existing change before inventing another ID patch. Do not claim a release or Ubuntu backport is available without checking that separately.

Sources: [current driver](https://github.com/torvalds/linux/blob/40288c9206c17eb66a603262e06a58d300d0f279/drivers/bluetooth/btusb.c), [v7.0 driver](https://github.com/torvalds/linux/blob/v7.0/drivers/bluetooth/btusb.c), [project's missing-entry document](https://github.com/ivoitovych/qca9377-bt-hang/blob/682d15c/docs/missing-quirks-entry.md).

## 2. The central interpretation needs three corrections

**DR-02 — High priority; confirmed source-level error in the size-mismatch explanation.**

The statements that 27-byte frames “do not fit” a 9-byte endpoint imply a transfer-size violation that the cited log does not demonstrate. In both v7.0 and current Linux, `__fill_isoc_descriptor()` explicitly fragments a buffer into per-packet chunks no larger than `mtu`. For `len=27, mtu=9`, it builds three 9-byte descriptors, at offsets 0, 9, and 18. `alloc_isoc_urb()` selects this function for alt settings other than 6.

Consequently `len 27 mtu 9` is not evidence that a single 27-byte USB packet was forced into a 9-byte endpoint. Nor does that line, on its own, identify a complete codec frame: its `len` is the host buffer length at that driver site. The observed alternate setting remains meaningful; the overflow/mismatch implication does not follow.

**Action:** describe “27-byte buffers split across a 9-byte isochronous endpoint.” Investigate timing, controller reassembly, SCO packetization, and command handling as distinct hypotheses. A descriptor trace or usbmon capture should show actual packets and completions before diagnosing a USB transport violation.

There is a second inference error in the bug-report summary: checking for alt 3 and subsequently using alt 1 does not establish that alt 3 is absent. The selection also requires a sufficient `sco_mtu` and `BTUSB_USE_ALT3_FOR_WBS`. Record each predicate separately. The accepted same-ID patch's descriptor listing includes alt 3, but that listing is another reporter's hardware and should not substitute for the local descriptor dump.

Sources: [driver helpers and selection](https://github.com/torvalds/linux/blob/40288c9206c17eb66a603262e06a58d300d0f279/drivers/bluetooth/btusb.c), [bug-report draft](https://github.com/ivoitovych/qca9377-bt-hang/blob/682d15c/docs/bug-report.md), [diagnostic wording](https://github.com/ivoitovych/qca9377-bt-hang/blob/682d15c/tools/bt-usbstate).

**DR-03 — High priority; causal overstatement, not a disproof of the hypothesis.**

EX-043 supports this sequence: synchronous setup is answered; later the host issues Disconnect; that command times out. The archived times are 16:51:17.081678 for the connection handle, 16:51:26.731743 for Disconnect, and 16:51:28.781675 for timeout. The command-to-timeout gap is approximately 2.050 seconds.

It does not establish that the command *caused* the wedge, or that the command processor was healthy throughout the preceding 9.65 seconds. A command processor already wedged during streaming produces the same trace: the next command is the first opportunity to discover it. Continued host submission, or even successful USB transfer, is not proof of healthy controller command processing. “Any command” is also untested generalization when the two identified timed-out commands are both Disconnect.

The first command plus timeout interval is informative about detection, but it is partly imposed by the timeout mechanism. Seven failures on one controller with two headsets support a reproducible association on that machine; they do not establish all-command causation or a model-wide failure rate.

**Action:** replace “a command into it does [wedge the controller]” with “the first observed subsequent command receives no response.” Distinguish Disconnect-specific failure, prior loss of command responsiveness, and generic command/stream interaction through controlled trials. Include successful post-link commands in the denominator, not only selected failures.

Sources: [EX-043](https://github.com/ivoitovych/qca9377-bt-hang/blob/682d15c/evidence/exhibits/043-first-command-into-alt1-stream-dies.md), [archived kernel log](https://github.com/ivoitovych/qca9377-bt-hang/blob/682d15c/evidence/sessions/20260917-234432-alt1-wedge-first-under-original-config/kernel.log), [BRIEF](https://github.com/ivoitovych/qca9377-bt-hang/blob/682d15c/BRIEF.md).

**DR-04 — Medium priority; regression and recovery claims exceed the comparisons.**

[`517b693351a2`](https://github.com/torvalds/linux/commit/517b693351a2) really changes the fallback policy. Its message says that it restores pre-5.8 behavior for devices without alt 6, with examples that work. Dating the path is not dating this hardware's regression. The v5.8–v5.11 comparison suppresses WBS; a non-failure there can simply mean the suspected workload never occurred.

The README also highlights the author's inability to find alt-6 adapters as an assumption this hardware falsifies. A device using alt 1 does not falsify that statement. The relevant proposition is fallback compatibility on adapters capable of WBS, qualified by firmware/setup state.

Likewise “no software recovery exists” should read “the tested recovery methods failed in the documented states.” The repository itself retains an early recovery and acknowledges that immediate kernel-callback timing was not tested. “CVSD is safe” should be limited to the successful observed controls.

**Action:** retain the candidate change and control window, but require matched exposure and a narrow contemporary-kernel comparison before asserting regression causality. Report recovery timing and outcomes individually.

## 3. Confirmed tooling defects

| ID | Priority | Finding | Verification |
|---|---|---|---|
| DR-05 | High | Capture rotation ignores a failed disk-space guard | Isolated execution of actual `main()` with `prune()` returning true at startup and false at rotation still opened a second capture |
| DR-06 | High | Incident collection declares sanitization success after sanitizer failure | Synthetic journal, sanitizer exiting 1: collector returned 0 and wrote `sanitised=yes` |
| DR-07 | High for evidence integrity | Trial shutdown probes the controller and abort deletes its directory | Current source confirms previously acknowledged R2-65 and R2-64 remain |
| DR-08 | Medium | Uninstall leaves `.disabled` configuration while declaring completion | Staged disabled modprobe file survived; exit 0 and `UNINSTALL COMPLETE` |
| DR-09 | Medium | `bt-usbstate` mistakes a different USB port for controller disappearance | Synthetic target at `1-2`, correct VID/PID: tool checked `3-3`, reported stage 2, exited 0 |
| DR-10 | Medium | EX-043's key packet-count derivation is not independently rerunnable from the committed session | Archived log lacks the `len 27 mtu 9` and alt-probe lines; exhibit's extraction depends on retained live journal |
| DR-11 | Medium | Capture timestamps and completeness need stronger contracts | Source uses userspace `time.time()`, ignores declared payload length, and writes a constant zero drops field |

### DR-05: failed retention check during rotation

In `bin/bt-capture`, startup uses `if not prune(...): return 1`. The rotation branch calls `prune(...)` and ignores its boolean result, then opens another file. If other data fills the disk during capture and pruning cannot restore the floor, the process continues despite the documented promise to stop. It may first discard retained captures without solving the shortage.

The reproduction replaced only the socket and filesystem-policy dependencies in memory, used a temporary directory, and forced immediate rotation. It observed two opened captures after return values `[True, False]`. This is control-flow proof, not a claim to have filled a real filesystem.

**Fix:** check the return value at every call site; stop with an explicit error before opening the next file. Add a startup-success/rotation-failure test. Existing startup and prune-only tests cannot detect this defect.

[Source](https://github.com/ivoitovych/qca9377-bt-hang/blob/682d15c/bin/bt-capture).

### DR-06: false sanitization status

`bt-incident` runs the sanitizer per file, suppresses its output, and does not accumulate failure. The manifest's `sanitised` value depends only on whether an executable sanitizer was found. Because the sanitizer correctly leaves originals untouched on failure, the collector can leave raw files next to a success manifest. This is already acknowledged as R2-77; it is independently reproduced here.

**Fix:** track per-file success, return nonzero on failure, and label the collection unpublishable. Do not infer success from executable presence. Include files generated after the sanitization loop in the publication review.

[Source](https://github.com/ivoitovych/qca9377-bt-hang/blob/682d15c/tools/bt-incident).

### DR-07: measurement still intervenes; abort still removes evidence

`bt-trial autostop` calls `hci_alive()`, which runs `timeout 6 hciconfig "$h" name`. Closing the trial also has additional liveness checks. The service executes autostop at shutdown. Thus changing `bt-state` to be probe-free did not make the trial lifecycle observational. The very premise of the new investigation is that a command may affect the state under study.

`abort` still executes `rm -rf "$dir"` and removes current state without checking whether the directory contains tracked or valuable evidence. This is especially inconsistent with the project's retention policy. Existing tests pin the current behavior; passing them does not settle its suitability.

**Fix:** record shutdown as censored/unknown based on passive evidence; make any active probe a separately recorded intervention. Preserve aborted trials with an explicit outcome and reason; refuse destructive removal of tracked material.

[Trial implementation](https://github.com/ivoitovych/qca9377-bt-hang/blob/682d15c/tools/bt-trial), [service](https://github.com/ivoitovych/qca9377-bt-hang/blob/682d15c/systemd/bt-trial-auto.service).

### DR-08: incomplete uninstall and unsupported restoration promise

The uninstaller's file list removes active names but not their `.disabled` siblings, which experiment mode deliberately creates. `verify-restored.sh` knows to flag them, but uninstall can still announce complete restoration. An isolated `BT_DESTDIR` reproduction confirmed this.

Separately, `install_file()` warns and overwrites an existing destination without backing it up. Uninstall later removes it. Therefore “No pre-existing file was ever modified” is not an enforced property on a machine with a collision. Generated configuration destinations need the same ownership treatment.

**Fix:** maintain ownership/baseline metadata, distinguish upgrades from unrelated files, and remove or restore owned active/disabled forms as appropriate. Derive the final success status from the restoration verifier. At minimum, refuse unmanaged collisions and make the summary conditional.

[Installer](https://github.com/ivoitovych/qca9377-bt-hang/blob/682d15c/install.sh), [uninstaller](https://github.com/ivoitovych/qca9377-bt-hang/blob/682d15c/uninstall.sh).

### DR-09: wrong-port false diagnosis and incorrect closure

`bt-usbstate` defaults `BT_USB_PATH` to `3-3`; it does not discover by `BT_VID`/`BT_PID`. With the same target placed at another synthetic port it reports the controller off-bus. The R2 disposition marked this fixed because `idVendor` appeared in the file, but here it is merely a printed attribute, not target resolution.

**Fix:** discover and validate the matching USB device; require a disambiguator for multiple matches; distinguish “configured path absent” from verified controller disappearance. Replace the text-count closure check with the behavioral fixture described above.

[Source](https://github.com/ivoitovych/qca9377-bt-hang/blob/682d15c/tools/bt-usbstate), [incorrect R2-88 closure](https://github.com/ivoitovych/qca9377-bt-hang/blob/682d15c/reviews/2026-09-19T1500Z-r2-disposition.md).

### DR-10: committed evidence does not preserve the complete derivation

The EX-043 session preserves the named command and timeout, and its USB-state file supports alt 1/9 bytes. However the committed `kernel.log` has no `len 27 mtu 9` or `Looking for Alt` lines. The collector's filter retains HCI/Bluetooth/USB keywords; standalone dynamic-debug lines may lack those keywords and be discarded. The exhibit explicitly depends on the live retained boot for its extraction.

Therefore I can verify the command timing and cached USB state from the public session, but cannot independently reproduce the claimed count of 910 buffers from that archive. The transcript is evidence of an earlier extraction, not a durable input on which a stranger can rerun it.

**Fix:** preserve the sanitized raw bounded window before semantic filtering, with absolute timestamps, tool revision, hash, command, and status. Generate summaries from that committed input. Keep historical exhibits intact and add corrective/supplementary exhibits.

[Collector filter](https://github.com/ivoitovych/qca9377-bt-hang/blob/682d15c/tools/bt-incident), [session](https://github.com/ivoitovych/qca9377-bt-hang/tree/682d15c/evidence/sessions/20260917-234432-alt1-wedge-first-under-original-config).

### DR-11: capture quality is adequate for some questions, not all

The code acknowledges that timestamps are userspace receive time. That warning is valuable, but the investigation now compares command ordering and intervals at tens of milliseconds. BlueZ's own monitor obtains `SCM_TIMESTAMP` with `recvmsg()` after enabling `SO_TIMESTAMP`; lack of a timestamp in the six-byte header is not lack of a kernel timestamp interface.

The collector also ignores `_plen`, accepts the received payload length without checking declared length, and fills the btsnoop drops field with zero. I did not demonstrate actual packet loss or truncation in these captures. The finding is that completeness is not instrumented sufficiently to support strong absence claims by itself.

**Fix:** use kernel ancillary timestamps, detect truncated/malformed records, expose capture discontinuities and available loss accounting, and distinguish unavailable loss information from measured zero. Preserve the decode-free architecture.

[Capture](https://github.com/ivoitovych/qca9377-bt-hang/blob/682d15c/bin/bt-capture), [BlueZ monitor implementation](https://github.com/bluez/bluez/blob/ebbb4ee31ad7011cead3d6394c68d10076ab55fc/monitor/control.c).

## 4. BlueZ patches: accept the narrow fixes

**0001 — no new blocking code issue found.** `start_discovery_complete()` dereferences `rp->type` in the no-client success branch before the existing length check. Management Command Status delivery can provide length zero and a null parameter. The new check is placed before the dereference and preserves the other branches. Returning without Stop Discovery when there is no valid returned type is appropriate defensive behavior; it does not purport to restore controller health or resolve the kernel's unusual success-status delivery.

**0002 — no new blocking code issue found.** The setup being present in `setups` does not imply its stream remains nonnull. The current source contains paths clearing `setup->stream`, while `avdtp_stream_set_transport()` dereferences its argument. The guard is after the existing I/O-error checks and uses the established drop path, retaining error precedence and cleanup behavior. It addresses the observed null lifetime state; it is not a proof against every possible asynchronous lifetime problem.

I ran the repository's application check on the newer BlueZ head: each patch alone, both orders, and both formatting checks passed—six checks total. I also ran current kernel `checkpatch.pl` under BlueZ's configuration: zero errors for each patch, but two warnings for 0001 and three for 0002. Those warnings concern quoted long lines and historical commits unavailable in the shallow BlueZ clone; the standalone checker also lacked its spelling dictionary. “No errors in this run” is more accurate than “warning-free.”

The repository reports four field guard firings for 0002. I reviewed the rationale and source; I did not independently replay the private cores or the complete 19-day daemon history. There are still no dedicated executable regression tests for these two callbacks in this review. Useful tests cover empty-client/short reply and valid setup/null stream, preserving ordinary success and I/O-error behavior. A callee null guard is optional defense in depth, not a reason to block this caller fix.

Direct patches: [0001](https://github.com/ivoitovych/qca9377-bt-hang/blob/682d15c/patches/bluez/0001-adapter-Fix-crash-on-short-start-discovery-reply.patch), [0002](https://github.com/ivoitovych/qca9377-bt-hang/blob/682d15c/patches/bluez/0002-a2dp-Fix-crash-on-NULL-stream-in-transport_cb.patch). Current upstream call sites: [adapter.c](https://github.com/bluez/bluez/blob/ebbb4ee31ad7011cead3d6394c68d10076ab55fc/src/adapter.c), [a2dp.c](https://github.com/bluez/bluez/blob/ebbb4ee31ad7011cead3d6394c68d10076ab55fc/profiles/audio/a2dp.c), [avdtp.c](https://github.com/bluez/bluez/blob/ebbb4ee31ad7011cead3d6394c68d10076ab55fc/profiles/audio/avdtp.c).

## 5. Tests, CI, and maintainability

The exact-head [GitHub Actions run](https://github.com/ivoitovych/qca9377-bt-hang/actions/runs/35462224146) completed successfully. My local `tests/run-tests` reported **6 failures out of 759 invariants**. Five were sanitization-related in an environment whose awk lacks the required interval support; the sixth was the capture no-socket test. Here Python lacks `socket.AF_BLUETOOTH`, causing an uncaught `AttributeError` rather than the expected controlled OSError refusal. Several hardware/tool contracts were explicitly skipped because `btmgmt`, `coredumpctl`, `hciconfig`, or `udevadm` was unavailable. This is not evidence that the exact-head CI report is false, and it is not a full local green run.

The suite's self-checks reported no tracked-file, evidence-session, trial-state, or system-binary changes. Its isolation work and explicit skipped-contract reporting are strengths. The successful CI round trip, however, is a clean-install scenario; it does not refute the disabled-file or pre-existing-file cases above.

The publication scan initially failed on the maintainer address because its allowlist prefers the reviewer's configured Git identity. This is a portability/configuration issue, not discovery of an unexpected private address. The follow-up scan passed with an explicit maintainer-address allowlist. A repository-maintained publication policy is more reproducible than deriving intended public identities from whoever invokes the command or authors the latest commit.

Two process improvements have high value:

1. Close findings with behavior-based tests. DR-09 shows why counting a token such as `idVendor` is not verification of the claimed fix.
2. Test negative transitions and composition. Startup-success/rotation-failure, sanitizer-failure/manifest-output, and experiment-mode/uninstall exercise boundaries that individually passing helper tests miss.

Large historical comment blocks and a monolithic suite make it difficult to see live control flow. Move narrative to linked history while preserving concise invariants at the relevant branch. Split tests only while retaining their shared isolation guards. Coverage floors are useful regressions alarms, not evidence of physical correctness or causal identification.

## 6. Recommended next work

| Order | Work | Completion criterion |
|---|---|---|
| 1 | Update upstream baseline and correct the 27/9 and command-causation wording | README, BRIEF, bug report, and diagnostic output agree with version-pinned sources |
| 2 | Fix capture rotation, sanitizer propagation, and trial interventions | Isolated negative-path reproductions fail before the fix and pass afterward |
| 3 | Fix uninstall ownership/disabled-file handling and USB target discovery | Staged experiment-mode removal and alternate-port fixtures pass |
| 4 | Preserve a complete sanitized fault window | Another machine can regenerate counts and timing from committed inputs without the original journal |
| 5 | Evaluate the accepted QCA entry in a controlled build | Firmware/setup path, command behavior, and recovery outcomes are recorded against the baseline |
| 6 | Separate streaming, generic commands, and Disconnect | Predeclared repeated trials include survival exposure and randomized command delay where practical |
| 7 | Add focused BlueZ callback regressions | Actual patched functions exercised with failing and ordinary inputs |

For the hardware comparison, record controller version/firmware information, selected alt setting, SCO MTU, negotiated parameters, USB packet descriptors/completions, HCI command/event trace, and first failure time. Compare the same contemporary source with and without the accepted setup change where feasible, keeping other configuration fixed. Treat firmware setup and timeout recovery as separate effects. A no-WBS control is useful for trigger avoidance but cannot alone identify the defective mechanism.

Finally, the project's rule to withhold a kernel report until a patch is ready is a project policy, not a technical requirement. A concise report of the exact observations, the newly located accepted commit, and the remaining uncertainty would let maintainers connect the two investigations. The report should not claim the root cause is established, and no such report was sent as part of this review.
