# What the build container had that the repository does not

Saved 2026-10-11 so that the TestFunctional measurement (results file, §T3) can be
retried on a machine with `/dev/kvm` without rediscovering these two pieces. Both are
container-local; neither is a repository tool.

| file | what it is | state |
|---|---|---|
| `pytest-bluezenv-0.1.9-env-no-kvm.diff` | a three-line change to the installed harness (`pytest_bluezenv/env.py`, the venv `cache/bluezenv-venv`): pass `-H` to `tools/test-runner` only when `/dev/kvm` exists. The harness always asks for the host CPU model, which QEMU refuses under TCG (`functional-pair_bredr-hostcpu/base.1.out`: `failed to initialize kvm`, then the CPU-model refusal). | made the guests boot under TCG; not enough — the host-side `btvirt` dropped every guest connection, because this container's kernel has no `AF_ALG` interface and `btdev_create()` needs one for an LE-capable controller (results file §T3, `../harness-diag/`). On a machine with a distribution kernel and KVM the diff is not needed. Not sent upstream: it papers over a local limitation, not a harness bug. |
| `build-tester-kernel.sh` | how the bzImage for the testers was built: bluetooth-next master with BlueZ's `doc/tester.config`, `make olddefconfig`, `make -j4 bzImage` (the same steps as the harness's own `build_kernel.py`). | used for every tester and functional run here; the kernel itself is `cache/bluetooth-next/arch/x86/boot/bzImage`, ignored, rebuilt by this script on a fresh checkout. |

Packages installed in the container for the work are listed in the appendix of the
results file.
