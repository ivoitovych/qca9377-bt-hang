# CO-02 — how the two mails are sent (prepared 2026-10-26, hardened 2026-10-27; nothing sent)

The BlueZ test depends on the kernel series: its "Reconnect During Disconnect" and "Connect
Twice" fail without it. Established practice, checked 2026-10-26:
- both go out the same day and point at each other; the test is not held back;
- BlueZ has landed tests for kernel bugs before (Pauli Virtanen: `e9b6ee380`, `80c8266ae`,
  `465108814`), saying so in the message;
- `submitting-patches.rst`: "Simply note 'this patch depends on patch X'".
Luiz Augusto von Dentz maintains both trees and is on copy for both mails, so he can apply them in
order. The BlueZ notes (below `---`, not part of the commit) ask for that order: "Please apply this
after that series is in bluetooth-next; until then the two cases fail there". The order matters
beyond tidiness: the kernel CI runs BlueZ master's testers on every kernel patch, so a test landed
first would show two failures on every unrelated submission until the series is in (reviewer 6,
2026-10-27). The notes also link the kernel series on lore. The link is known only once the series
is sent, so the mail carries the placeholder `@KERNEL_SERIES_LINK@` until then.

## The tools
- `send.sh <package send dir> kernel|bluez [--send|--check]`: one script for the dry run and the
  real send, so the command that sends is the command that was dry-run. It prints the package
  directory and each mail's subject first.
  - Without a flag: `git send-email --dry-run`. Any package may be dry-run.
  - `--send`: the real send. `git send-email --confirm=always` asks before each mail. The
    operator's to run, on their own decision.
  - `--check`: every guard `--send` applies, then stop.
  - The guards (`--send` and `--check`): the package must be the one named in
    `chosen-package` (one line, relative to this contribution, e.g. `patch/v7-candidate/send`;
    the file does not exist until the operator chooses); its mails must be tracked and committed,
    with nothing untracked beside them; `kernel/` must hold exactly the cover and patches 1 to 3,
    `bluez/` exactly one mail; the BlueZ mail must have no placeholder left and exactly one lore
    link to a cover letter of this author.
  - A failed `git send-email` ends the script with its exit status and a warning, never with the
    "next step" line. An unknown option is refused, not treated as a dry run.
  - Recipients as decided on 2026-10-22, the same as `tmp/co02-round3/send-dry-run.sh`'s; the dry
    runs of both agree.
  - Tested 2026-10-27, nothing sent: dry runs of the v7 kernel and BlueZ mails (recipients as
    before); refused: a fifth `.patch` file in `kernel/`, an empty `bluez/`, a misspelt option,
    no `chosen-package`, a package other than the chosen one, a chosen package with uncommitted
    changes; a dry run whose `git send-email` failed exited 1 with "FAILED".
- `fill-bluez-link.sh <package send dir> <cover Message-ID>`: puts
  `https://lore.kernel.org/linux-bluetooth/<id>/` in place of the placeholder. It refuses an ID that
  is not this author's cover (the cover's ID has `-1-` before the author's address; a patch's
  `-2-` was refused in the test), a package without exactly one BlueZ mail, and a mail without
  exactly one placeholder (a second fill was refused). It cannot know whether the ID is the cover
  that was just sent: the BlueZ mail's own ID also has `-1-`, so take the ID from the
  `[PATCH 0/3]` mail of the kernel send, and open the link.

## The order, on the day (the operator's yes first)
1. Fetch bluetooth-next and BlueZ master. If either moved, regenerate and repeat the checks.
2. Write the chosen package into `chosen-package` and commit it.
3. `send.sh <dir> kernel --check`, then `send.sh <dir> kernel` (the dry run; read the
   recipients).
4. `send.sh <dir> kernel --send`. Answer `y` to each of the four mails. If any answer is not
   `y`, quit (`q`) and stop: git send-email gives each mail its Message-ID before the prompt, so a
   declined cover leaves the patches threading to a mail that was never sent (reviewer 6). Check
   lore before any new attempt. Note the Message-ID printed for `[PATCH 0/3]`.
5. `fill-bluez-link.sh <dir> '<that Message-ID>'`. Open the printed link: lore shows the series
   after a few minutes; it must be `[PATCH 0/3] Bluetooth: hci_conn: fix SCO connection reuse`
   with its three patches.
6. Commit the filled BlueZ mail.
7. `send.sh <dir> bluez --check`, then `send.sh <dir> bluez` (the dry run), then
   `send.sh <dir> bluez --send`.
