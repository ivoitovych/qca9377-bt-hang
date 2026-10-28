# Does the BlueZ functional harness touch the host's Bluetooth? (checked 2026-10-28, nothing run)

Paths are under `cache/bluez-upstream` (the BlueZ tree) unless marked `scripts/`.

## Answer

By its documented design the harness creates **no virtual controller on the host kernel**:
the controllers (`btvirt`, run on the host) are plain user-space emulators reached over a
UNIX socket, and the HCI device (`hci0`) is registered only by the **guest** kernel inside each
QEMU VM. The host's `/dev/vhci` is used only if `btvirt` is started with `-l`, and the one
place that does that (`tools/test-runner.c:1355`) runs inside the guest. One gap: the
code that starts the host `btvirt` is in the PyPI package `pytest-bluezenv`, which is **not on
this disk** (no venv at `cache/bluezenv-venv`), so its exact `btvirt` flags are known from the
documentation, not from source.

## Evidence

1. Architecture, host side. `doc/test-functional.rst:166-188`: the pytest process "never runs
   Bluetooth code itself; it only drives the VM hosts"; each VM host is a `test-runner`
   instance, a QEMU VM. `doc/test-functional.rst:228-231`: "a single `btvirt` process runs on
   the developer machine and provides an emulated BR/EDR/LE controller to every VM host over a
   UNIX socket".
2. `btvirt` socket mode opens only AF_UNIX (or, with `-t`, TCP) listeners:
   `emulator/server.c:330,337,340` (`socket(PF_UNIX…)`, `bind`); `emulator/main.c:254-285`
   (`server_open_unix` for the `-s` mode). Neither opens `/dev/vhci`.
3. `/dev/vhci` is opened in exactly one place, `emulator/vhci.c:136`, reached from
   `emulator/main.c:230-233` only when `-l[N]` is given (`main.c:167-172`).
4. The `-l` option is passed by `tools/test-runner.c:1355` (`"-l%d"`, `start_btvirt`, called at
   `:1541` when `num_emulator` is set). That function runs in `main` after the guest has booted
   as PID 1 (`doc/test-runner.rst:86-95`: `init=<test-runner>`), so it is the guest's
   `/dev/vhci`, on the guest kernel.
5. How a VM gets its controller from the host's `btvirt`: the socket is attached as a second
   virtio console (`doc/test-runner.rst:104-122`), and in the guest `tools/test-runner.c:1504-1513`
   puts the H:4 line discipline on `/dev/hvc1` (`attach_proto`, `HCI_UART_H4`), so the guest's
   `hci_uart` registers `hci0`. The host kernel sees only a unix-socket peer.
6. `--usb`/`--pcie` are opt-in and pass a REAL host USB/PCIe controller through (`usb-host`,
   `vfio-pci`, which "requires running the tests as root"): `doc/test-functional.rst:243-246`,
   `:325-330`; `doc/test-runner.rst:124-127`. These would unbind/take the host's adapter. Never
   pass them here (the laptop's own adapter would be taken away from the host).
7. `scripts/functional-repeat.sh:103` runs `test/test-functional ... --kernel <bzImage>` with
   neither option, and `:85` only reports `/dev/kvm` presence. The test selection comes from
   `-k`. `test/test-functional:18-20` is just `python3 -m pytest test/functional`.
   `test/functional/conftest.py` contains no `btvirt`, `vhci`, `kvm` or `AF_ALG` reference
   (grep, 2026-10-28).

## What it needs

| need | where | notes |
|---|---|---|
| `qemu-system-x86_64` | `doc/test-functional.rst:20,261` | `-machine type=q35,accel=kvm:tcg` (`tools/test-runner.c:856`), so KVM is optional: it falls back to TCG, slow, timings change |
| `/dev/kvm` | `doc/test-functional.rst:266` ("Recommended"); `scripts/functional-repeat.sh:24-26,85` | present on this host now (`crw-rw----+ root:kvm 10,232`); the CO-11 `README.md` says only that a run has never completed here and that it needs `/dev/kvm` and `AF_ALG` |
| `AF_ALG` | `src/shared/crypto.c:90,112` (`socket(PF_ALG, SOCK_SEQPACKET…)`), used by `bt_crypto_new` | `emulator/btdev.c:8377-8381`: for the BR/EDR+LE and LE controller types `btdev_create` returns NULL if it fails, so the host `btvirt` needs AF_ALG; the guest kernel needs `CONFIG_CRYPTO_USER_API*` (`doc/tester.config:50-52`). AF_ALG is a user-space crypto interface; it creates no network or Bluetooth device |
| guest kernel | `doc/test-functional.rst:294-318`; `doc/tester.config` | `--kernel <bzImage>` or `--kernel-build` (which downloads kernel sources under `test/.pytest_cache`) |
| `virtiofsd` (else 9p) | `doc/test-runner.rst:62-81` | the guest root is the host `/` read-only |
| `dbus-daemon`, python `pytest>=8`, `pytest-bluezenv==0.1.6` | `doc/test-functional.rst:262,279-280`; `test/functional/requirements.txt` | `pip` install: use a venv, never the host python |
| built BlueZ tree | `scripts/functional-repeat.sh:97-99` | `--enable-asan --enable-ubsan` build |

## Is the host touched at all?

- Bluetooth: no, as long as `--usb`, `--pcie`, `--force-usb`, `--force-pcie` are not given and the
  host `btvirt` is not started with `-l` (cannot be confirmed from source here, see above;
  a running `btvirt` plus new `hciN` in `btmgmt`/`/sys/class/bluetooth` on the host would show it).
- It does touch: `/tmp/pytest-bluezenv-*/` (shared dirs, `doc/test-functional.rst:159-161`),
  host CPU/RAM (about 400 MB per VM, `conftest.py:211-218`, up to 3 VMs per test),
  a host `btvirt` process, and a read-only export of the host `/` to the guests.
- `/dev/vhci` exists on the host (`crw------- root`); a stray `btvirt -l` would create a host `hciN` and make `bluetoothd` on
  the laptop see a second adapter.

## Safe way to run it

Run everything inside a container so the host has no path to `/dev/vhci`, the real adapter, or the host `bluetoothd`:

1. Docker `ubuntu:24.04` image with `qemu-system-x86`, `virtiofsd`, `dbus`, `python3-venv`, build deps, and the
   kernel image mounted in; no `--privileged`, no `--net=host`, no `-v /dev`, no `-v /run/dbus`.
   Pass only `--device /dev/kvm` (optional; without it QEMU uses TCG).
   The container's `/` is then what the guests see, not the host's.
2. Do not mount `/dev/vhci` (Docker does not expose it by default) and do not add USB/PCIe devices.
   With no `/dev/vhci` in the container, a stray `btvirt -l` fails with "Failed to open Virtual HCI device"
   (`emulator/main.c:235`) instead of touching the host.
3. Before the run, record the host's adapter list (`bluetoothctl list`, read-only) and
   `ls /sys/class/bluetooth`; compare after. Run with the Docker `--rm` and a user-chosen
   `--name`, so the container can be killed.
4. Take the run script from `scripts/functional-repeat.sh` unchanged; it needs `--kernel <bzImage>`, which the
   project does not have yet (no kernel image with `doc/tester.config`).

Nothing was executed for this check; it is a read of the files named above.
