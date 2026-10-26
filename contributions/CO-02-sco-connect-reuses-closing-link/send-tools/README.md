# CO-02 — how the two mails are sent (prepared 2026-10-26; nothing sent)

The BlueZ test depends on the kernel series: its "Reconnect During Disconnect" and "Connect
Twice" fail without it. Established practice, checked 2026-10-26:
- both go out the same day and point at each other; the test is not held back;
- BlueZ has landed tests for kernel bugs before (Pauli Virtanen: `e9b6ee380`, `80c8266ae`,
  `465108814`), saying so in the message;
- `submitting-patches.rst`: "Simply note 'this patch depends on patch X'".
Luiz Augusto von Dentz maintains both trees and is on copy for both mails, so he can apply them in
order. The BlueZ notes (below `---`, not part of the commit) ask for that order: "Please apply this
after that series is in bluetooth-next; until then the two cases fail there". They also link the
kernel series on lore. The link is known only once the series is sent, so the mail carries the
placeholder `@KERNEL_SERIES_LINK@` until then.

## The tools
- `send.sh <package send dir> kernel|bluez [--send|--check]`: one script for the dry run and the
  real send, so the command that sends is the command that was dry-run.
  - Without a flag: `git send-email --dry-run`.
  - `--send`: the real send. `git send-email --confirm=always` asks before each mail. The
    operator's to run, on their own decision.
  - `--check`: only the guard `--send` applies. The BlueZ mail is refused while it still has the
    placeholder. Tested 2026-10-26: refused unfilled, passed filled.
  - Recipients as decided on 2026-10-22, the same as `tmp/co02-round3/send-dry-run.sh`'s; the dry
    runs of both agree.
- `fill-bluez-link.sh <package send dir> <cover Message-ID>`: puts
  `https://lore.kernel.org/linux-bluetooth/<id>/` in place of the placeholder. It refuses an ID that
  is not this author's cover (the cover's ID has `-1-` before the author's address; a patch's
  `-2-` was refused in the test), and it refuses a mail without exactly one placeholder (a second
  fill was refused). Caution: the BlueZ mail's own ID also has `-1-`, so take the ID from the
  `[PATCH 0/3]` mail of the kernel send.

## The order, on the day (the operator's yes first)
1. Fetch bluetooth-next and BlueZ master. If either moved, regenerate and repeat the checks.
2. `send.sh <dir> kernel`: the dry run; read the recipients.
3. `send.sh <dir> kernel --send`: the kernel series. Note the Message-ID printed for
   `[PATCH 0/3]`.
4. `fill-bluez-link.sh <dir> '<that Message-ID>'`. Then open the printed link: lore shows the
   series after a few minutes.
5. `send.sh <dir> bluez --check`, then `send.sh <dir> bluez` (the dry run), then
   `send.sh <dir> bluez --send`.
6. Commit the filled BlueZ mail as sent.
