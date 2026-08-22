# Source access — what can be obtained, from where, and what cannot

**Why this file exists.** Work on this record kept being deferred with "we would
need the source" or "we would need debug symbols". It turns out almost all of it
is obtainable, and the one time it was not, that was worth knowing precisely
rather than vaguely. This file records the route so nobody re-derives it, and
states the gaps honestly so nobody plans around a capability we do not have.

Everything below was executed and verified on 2026-08-23.

---

## 1. What is reachable

Outbound HTTPS goes through a proxy with an allowlist. Most of the open web is
**not** reachable, but the Ubuntu archives are — and they are what actually
matters here.

| host | status | what it gives |
|---|---|---|
| `archive.ubuntu.com` | ✅ reachable (HTTP **and** HTTPS) | every source and binary package |
| `security.ubuntu.com` | ✅ reachable | security-pocket packages |
| `ddebs.ubuntu.com` | ✅ reachable | **debug symbol packages** |
| `ports.ubuntu.com` | ✅ reachable | non-amd64 architectures |
| `pypi.org`, `registry.npmjs.org`, `index.crates.io`, `proxy.golang.org` | ✅ reachable | language package registries |
| `git.kernel.org`, `www.kernel.org`, `bugzilla.kernel.org` | ❌ 403 at the proxy | — |
| `github.com` | ❌ 403 at the proxy | — |
| `bugs.launchpad.net`, `launchpadlibrarian.net` | ❌ 403 at the proxy | — |
| `askubuntu.com`, `wiki.archlinux.org` | ❌ 403 at the proxy | — |

**The practical consequence.** *Source code* is not a problem — the Ubuntu
archive carries the full source of everything on this machine, at the exact
packaged version. *Third-party discussion* — forums, bug trackers, wikis — is
the thing that cannot be reached, which is precisely why
[`related-reports.md`](related-reports.md) carries a per-entry verification
status instead of a list of links.

## 2. BlueZ — the exact version that crashes, source and binary

```console
$ base=http://archive.ubuntu.com/ubuntu/pool/main/b/bluez
$ curl -O $base/bluez_5.72.orig.tar.xz
$ curl -O $base/bluez_5.72-0ubuntu5.5.debian.tar.xz
$ curl -O $base/bluez_5.72-0ubuntu5.5.dsc
$ curl -O $base/bluez_5.72-0ubuntu5.5_amd64.deb        # the binary that crashed
```

Verify before trusting it — the `.dsc` carries the checksums:

```console
$ sha256sum -c <(awk '/^Checksums-Sha256:/{f=1;next} /^[A-Za-z-]+:/{f=0} f&&NF==3{print $1"  "$3}' \
                 bluez_5.72-0ubuntu5.5.dsc)
bluez_5.72.orig.tar.xz: OK
bluez_5.72-0ubuntu5.5.debian.tar.xz: OK
```

Unpacking `.debian.tar.xz` over the source tree gives `debian/patches/series` —
**31 Ubuntu patches**. This matters: upstream 5.72 is *not* what runs here.
Two of the 31 are worth knowing about by name when reading crash reports:

```
agent-Assert-possible-infinite-loop.patch
shared-gatt-client-Fix-segfault-after-PIN-entry.patch
```

⚠️ **Do not read upstream BlueZ and call it "what we run".** Ground rule 1 of the
[external review brief](external-review-brief.md) exists for this.

## 3. Kernel — two traps, and both of them bit

> ⚠️ **Corrected 2026-08-23.** The first version of this section named the wrong
> source package and the wrong running kernel. Both errors are described below
> rather than quietly overwritten, because both are easy to repeat.

### Trap 1 — this machine runs the HWE kernel, so `linux` is the wrong package

The source package is **`linux-hwe-7.0`**, not `linux`. They are different files:

```
linux_7.0.0-30.30.diff.gz              2015294 bytes  sha256 35f9f529…   ← WRONG
linux-hwe-7.0_7.0.0-30.30~24.04.1.diff.gz  1988323 bytes  sha256 91a45f5c…   ← right
```

The correct fetch, verified against the publisher's own `Checksums-Sha256`:

```console
$ base=http://archive.ubuntu.com/ubuntu/pool/main/l/linux-hwe-7.0
$ curl -sO $base/linux-hwe-7.0_7.0.0-30.30~24.04.1.dsc
$ curl -sO $base/linux-hwe-7.0_7.0.0-30.30~24.04.1.diff.gz
$ grep -q "$(sha256sum linux-hwe-7.0_7.0.0-30.30~24.04.1.diff.gz | awk '{print $1}')" \
       linux-hwe-7.0_7.0.0-30.30~24.04.1.dsc && echo OK
OK
```

The `.orig.tar.gz` is the same mainline tarball either way (254937830 bytes), so
only the delta has to come from the right package. Stream it and extract just the
paths in the walk of shame — **4.3 MB** instead of a 1.5 GB tree:

```console
$ curl -s $base/linux-hwe-7.0_7.0.0.orig.tar.gz | tar -xz --wildcards \
      'linux-7.0/net/bluetooth/*' 'linux-7.0/drivers/bluetooth/*' \
      'linux-7.0/include/net/bluetooth/*' 'linux-7.0/drivers/usb/core/*'
```

The tarball's top-level directory is `linux-7.0/`; **paths inside the delta are
prefixed `linux-hwe-7.0-7.0.0/`**, so strip levels accordingly when patching.

**The Ubuntu delta is not optional.** It patches the files this investigation
cares about most (counts from the `-30` HWE delta):

| file | hunks |
|---|---|
| `drivers/bluetooth/hci_qca.c` | 11 |
| `net/bluetooth/hci_sync.c` | 9 |
| `net/bluetooth/hci_event.c` | 8 |
| `net/bluetooth/l2cap_core.c` | 7 |
| `net/bluetooth/hci_conn.c` | 4 |
| `drivers/bluetooth/btusb.c` | 4 |
| `net/bluetooth/sco.c` | 3 |

### Trap 2 — "the machine runs `-28`" was stale, and five exhibits carried it

The investigation machine has run **three** kernels during this project:

| boots | dates | kernel |
|---|---|---|
| −15 … −4 | 2026-08-13 → 08-17 | `7.0.0-28-generic` |
| −3, −2 | 08-19, 08-21 | `7.0.0-29-generic` |
| −1, 0 | 08-22 → | `7.0.0-30-generic` |

So `-30` **is** the machine today; it is not "one bump ahead" of it, as this file
previously claimed. But `EX-030`–`EX-032` were captured under `-28`, which is
superseded and **gone from `archive.ubuntu.com`**.

`-28` survives only on Launchpad, which is one of the 403 hosts here. The
investigation machine can reach Launchpad in 0.24 s, and has fetched and verified
the `-28` delta into the shared cache — see
[`external-cache.md`](external-cache.md) and `external-cache-manifest.tsv`.

**The rule that follows:** a line number is meaningless without the build it was
read in. Say `-28`, `-29` or `-30` explicitly, every time.

## 4. Debug symbols — where the archive helps, and where it does not

`ddebs.ubuntu.com` is reachable and carries `bluez-dbgsym`. But:

```
bluez-dbgsym_5.72-0ubuntu5_amd64.ddeb        ✅  present
bluez-dbgsym_5.72-0ubuntu5.5_arm64.ddeb      ✅  present
bluez-dbgsym_5.72-0ubuntu5.5_armhf.ddeb      ✅  present
bluez-dbgsym_5.72-0ubuntu5.5_ppc64el.ddeb    ✅  present
bluez-dbgsym_5.72-0ubuntu5.5_riscv64.ddeb    ✅  present
bluez-dbgsym_5.72-0ubuntu5.5_s390x.ddeb      ✅  present
bluez-dbgsym_5.72-0ubuntu5.5_amd64.ddeb      ❌  DOES NOT EXIST
```

Confirmed against the package indices, not just a directory listing: for amd64,
`noble` has `5.72-0ubuntu5` and `noble-updates` has **no `bluez-dbgsym` at all**.
Ubuntu published `-0ubuntu5.5` debug symbols for five architectures and not for
the one almost everybody runs.

**And the older symbols cannot be substituted.** That was measured, not assumed:

```
first differing byte in exec segment: 0x28286
differing bytes: 927682 of 991277  (93.585%)
```

The two builds share a size but not a layout. Carrying an address from one to
the other would have produced a confident wrong answer.

### What works instead

Stripping removes the symbol table; it does **not** remove:

- **`.eh_frame`** — unwind info, which yields exact function start/end addresses
  (3239 of them in `bluetoothd`);
- **`.dynsym` + `.rela.plt`** — so every PLT call is still named.

A function can therefore be fingerprinted by *size plus its multiset of call
targets* and matched against a symbolised build of a neighbouring version, then
confirmed against the disassembly and the source. That is how `EX-032` was
resolved: [`reviews/2026-08-23T2340Z-ex032-crash-sites-resolved.md`](../reviews/2026-08-23T2340Z-ex032-crash-sites-resolved.md).

`bluetoothd` ships **no `.gnu_debugdata`** (MiniDebugInfo) — that is a Fedora
practice, not an Ubuntu one. Do not go looking for it.

## 5. Reading a `segfault` line correctly

Modern kernels print three values, and the first is the one that is useful:

```
in bluetoothd[367e5,60ff12bd7000+f3000]
              ^      ^            ^
              |      |            +-- mapping size
              |      +--------------- mapping start
              +---------------------- FILE OFFSET of the faulting instruction
```

The file offset is `ip - vm_start + (vm_pgoff << PAGE_SHIFT)`. It is **not**
`ip - vm_start`, and treating it as such sends you to the wrong function.

Recomputing it is also a free integrity check on the binary you downloaded: if
your copy's executable segment does not reproduce the reported mapping size, it
is not the build that crashed.

## 6. What genuinely still needs the machine

Not solvable from here at any effort:

- anything requiring the running system — `EX-027`/`EX-028` power-off vs reboot,
  the M.2 rail question, `btmgmt`/`hciconfig` output;
- ~~the exact `-28` kernel build~~ — **solved**: fetched from Launchpad by the
  investigation machine and verified into the shared cache
  ([`external-cache.md`](external-cache.md));
- `-0ubuntu5.5` amd64 debug symbols, which do not exist anywhere;
- **anything about the GNOME layer**, which this project captures no logs from at
  all — see [`source-map.md`](source-map.md).

## 7. Where the downloads go

Into a scratch directory outside the repository. **Source trees, `.deb`s and
`.ddeb`s are never committed** — they are large, they are not ours, and
`devtools/repo-scan` refuses non-text files by content for good reason. Findings
come back as text in `reviews/`; the fetch commands above are the reproduction.
