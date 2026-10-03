# EX-061 — dc16388d45ec-queued-for-seven-stable-lines

**Claim.** The stable team queued dc16388d45ec (Bluetooth: btusb: Add IMC Networks QCA9377 to quirks table) for all seven live stable lines - 7.2, 6.18, 6.12, 6.6, 6.1, 5.15 and 5.10 - in reply to this project's backport request of 2026-10-02; the patch file is present in queue-<v>/ of the public stable-queue tree for each line.

**Relevance.** This is the stable maintainer's reply ('Queued for 7.2, 6.18, 6.12, 6.6, 6.1, 5.15 and 5.10, thanks.') checked against the queue itself rather than taken on the mail's word. The request asked for five lines and offered the two older ones; the cherry-pick and build of all seven was recorded in EX-059. A queued patch leaves queue-<v>/ when that stable release is cut, so a later re-run that prints 'not in queue' means released or dropped, and needs releases/<v>.<n>/ to tell which.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/stable-queue-check.sh bluetooth-btusb-add-imc-networks-qca9377 7.2 6.18 6.12 6.6 6.1 5.15 5.10
```

## Output

Verbatim, 8 line(s), exit status 0.

```
7.2    QUEUED  bluetooth-btusb-add-imc-networks-qca9377-to-quirks-t.patch
6.18   QUEUED  bluetooth-btusb-add-imc-networks-qca9377-to-quirks-t.patch
6.12   QUEUED  bluetooth-btusb-add-imc-networks-qca9377-to-quirks-t.patch
6.6    QUEUED  bluetooth-btusb-add-imc-networks-qca9377-to-quirks-t.patch
6.1    QUEUED  bluetooth-btusb-add-imc-networks-qca9377-to-quirks-t.patch
5.15   QUEUED  bluetooth-btusb-add-imc-networks-qca9377-to-quirks-t.patch
5.10   QUEUED  bluetooth-btusb-add-imc-networks-qca9377-to-quirks-t.patch
checked 2026-10-03 19:43 UTC against https://git.kernel.org/pub/scm/linux/kernel/git/stable/stable-queue.git/tree/queue-<v>
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-10-03T21:43:56+02:00` |
| kernel | `7.0.0-34-generic` |
| capture boot id | `c34cfa10` |
| evidence boot ids | none named by the command (it selects by index or not by boot) — see the window above |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
