# 4C: active journald on a booted noble system (QEMU/KVM guest)

Result: **no omissions, no duplicates, no ordering errors, and no difference between stock and patched.** In each phase two
writers of 24000 numbered messages each were fully present, once each, in order, in both `journalctl -f` and a later full
read; `journalctl --verify` passed every file; both builds produced identical output on the final static journal.

## Guest

Official Ubuntu 24.04 (noble) server cloud image, run under QEMU/KVM (4 vCPU, 4 GiB, user-mode network only, no host
devices, no shared host directories; the data goes in as a read-only ISO, the results come out on a raw disk), started at
`nice -n 19 ionice -c 3` (`run-4C.sh`). cloud-init runs `vm-run.sh` at first boot. Guest kernel 6.8.0-147-generic.

Downloaded (`fetch-cloud-image.sh`; kept in the work directory, not in the repository):

| item | value |
|---|---|
| file | `noble-server-cloudimg-amd64.img` |
| source | https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img |
| size | 621284352 bytes |
| sha256 | `04e8f2461a16a44e78a370284471f29616cdd9baf1893df25807b71f985b6c94` |
| check | `sha256sum -c` against that directory's `SHA256SUMS` (copy here): `noble-server-cloudimg-amd64.img: OK` |
| Last-Modified header | Sat, 17 Oct 2026 13:17:16 GMT |

The image ships systemd 255.4-1ubuntu8.18; `vm-run.sh` first upgrades to **stock 255.4-1ubuntu8.19 from noble-proposed**
(apt pin priority 1, the guest's own network), then later installs **the 8.20 test debs** (systemd, systemd-sysv,
systemd-dev, libsystemd0, libsystemd-shared, libudev1, udev, libpam-systemd, libnss-systemd, systemd-resolved,
systemd-timesyncd, systemd-journal-remote) over it. Hashes: `../scripts/PACKAGES.txt`.

## Method

journald configuration (`/etc/systemd/journald.conf.d/50-verify.conf`): persistent storage, `SystemMaxFileSize=1M`,
`SystemMaxUse=400M`, `SystemMaxFiles=1000`, no rate limit. Per phase (stock, then patched; journald restarted by the
package upgrade):

1. `journalctl -f -o cat -a -n 0` is started and left running;
2. two writers start together, each logging 24000 numbered lines (`MARK <tag> <number> <padding>`, 5 ms apart, about 200
   lines per second each): one as a system service, one in the user session of `ubuntu` (user manager, so its messages go to
   the `user-1000` journal files);
3. while they run, `journalctl --rotate` is issued three times (30 s, 70 s, 110 s), in addition to the size rotations;
4. after the writers end: `journalctl --sync`, 8 s, stop the follower, a full `journalctl -o cat -a` read;
5. `analyse.py` checks every number 0..23999 of each tag: missing, duplicates, out-of-order steps; then `journalctl --verify`.

Finally journald is stopped and both journalctl builds (the installed 8.20 one and the unpacked stock 8.19) read the
static directory: `-o export`, `-o export -r`, `-o cat -a`, compared by sha256 with exit statuses.
Termination: the writers finish by themselves (a bounded count); the follower is stopped by the script (exit status 143
expected); the VM stops itself after writing its results.

## Table (from `summary.txt`)

| phase / build | reader | stream | expected | lines | missing | duplicates | out-of-order |
|---|---|---|---|---|---|---|---|
| stock 8.19 | full read | system | 24000 | 24000 | 0 | 0 | 0 |
| stock 8.19 | full read | user session | 24000 | 24000 | 0 | 0 | 0 |
| stock 8.19 | `journalctl -f` | system | 24000 | 24000 | 0 | 0 | 0 |
| stock 8.19 | `journalctl -f` | user session | 24000 | 24000 | 0 | 0 | 0 |
| patched 8.20 | full read | system | 24000 | 24000 | 0 | 0 | 0 |
| patched 8.20 | full read | user session | 24000 | 24000 | 0 | 0 | 0 |
| patched 8.20 | `journalctl -f` | system | 24000 | 24000 | 0 | 0 | 0 |
| patched 8.20 | `journalctl -f` | user session | 24000 | 24000 | 0 | 0 | 0 |

Files at the end of a phase: 38 after the stock phase (19 user), 76 after the patched phase (38 user; the stock phase's
files remain, so the patched full read covers 76 files); journalctl exit status 0 everywhere, empty stderr,
`journalctl --verify` 38 of 38 and 76 of 76 PASS, no `.journal~` files.

Final static journal (76 files): `-o export` `f918d9ab360e6656` both, `-o export -r` `5ec92207de5c06c9` both, `-o cat -a`
`78722850db960cf3` both (first 16 hex digits of sha256), exit 0 both: SAME.

## Notes

* A first VM run is not used: its user-session writer was started from a directory the unprivileged user cannot read and
  wrote nothing; the script was fixed and the whole run repeated from a fresh copy of the image.
* The raw outputs (about 10 to 20 MB each) stay in the work directory; their sha256 are in `OUTPUT-SHA256.txt`.
* Scope: one VM, two streams, rotations by size (the file counts above) and 3 by request per phase. It shows that the two commits cause no
  loss, duplicate or reorder with journald writing and rotating concurrently with a reader; it does not exercise vacuuming
  of files under a reader (that is 4B).
