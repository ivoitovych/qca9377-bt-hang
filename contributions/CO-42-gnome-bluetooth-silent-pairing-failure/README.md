# CO-42 — gnome-bluetooth: a failed setup shows the user nothing (U29, U13)

**What:** `create_callback()` in `lib/bluetooth-settings-widget.c` handles a failed `Pair()` with
FIXME comments only. On master `adf070af`:
- `AuthenticationRejected` (U29) gives one `g_warning`;
- `AuthenticationFailed` (U13) and `AuthenticationCanceled` give nothing at all.

The row stays "Not Set Up", and no dialog, toast or banner appears. Ubuntu's 46.0-1ubuntu1 is the
same.

**Upstream state (read 2026-11-07):**
- Issue #18 "Show error when pairing or connecting fails" has been open since 2009.
- Two earlier MRs, !37 and !135, were closed.
- MR !137 (another author, opened 2022, rebased 2025-02-23, open, no maintainer reply since)
  adds toasts for Failed and Canceled.
- So this is not a new report: our part would be evidence on #18 or !137.

**State (2026-11-08): reproduced; a comment drafted, local only; nothing posted.**
- **Measured** (Fedora 45 container, the real widget against python-dbusmock's bluez5 template):
  - With !137 applied unchanged, Failed and Canceled show a toast, and Rejected still shows
    nothing.
  - Edge runs on !137:
    - a device removed while `Pair()` is pending gives a GLib critical warning (not a crash)
      in 6 of 6 runs, and none on master;
    - a deliberate Cancel can show a "failed" toast (mocked; real BlueZ's reply not checked).
- **Draft comment for !137:** `tmp/u29-gnome/mr-137-comment-draft.md`, uncommitted. Whether it
  is kept, committed or posted is the operator's call. Before any post:
  - fill in !137's head commit from the MR page (the GitLab API refused automated reads on
    2026-11-08);
  - if the MR has changed, rerun the tests on its latest diff.

**Open choices (the operator):**
- a comment on !137 or #18 with the results;
- the operator's own patch, tested with our harness (Rejected, device removal, cancel);
- or nothing yet.

A posted comment means a public exchange on the other author's MR. gnome-bluetooth and the
GNOME handbook set no project rule on assisted contributions (read 2026-11-07).

**Related, BlueZ side:** master's `Device1.Disconnected` reason `org.bluez.Reason.Authentication`
(`53db78000`, 5.83) could tell the user why. It is not raised for status 0x05, so evaluate it
before resuming the 2021 agent-API thread.

**Decides:** the operator, who writes and posts anything.

**Refs:**
- `docs/issues.md` U29 and U13;
- `results/u29-gnome-pairing-feedback-2026-11-07/`, with the raw runs in
  `/root/exp/agent-work/u29-g1-gnome-pairing-feedback/`;
- reviews `reviews/2026-11-07T1515Z-u29-reviewer-2-fourth-message-verbatim.md` and
  `reviews/2026-11-07T2000Z-u29-reviewer-2-fifth-message-verbatim.md`.
