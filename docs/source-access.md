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

## 3. Kernel — and the trap in reading mainline

```console
$ base=http://archive.ubuntu.com/ubuntu/pool/main/l/linux
$ curl -s $base/linux_7.0.0.orig.tar.gz | tar -xz --wildcards \
      'linux-7.0/net/bluetooth/*' 'linux-7.0/drivers/bluetooth/*' \
      'linux-7.0/include/net/bluetooth/*' 'linux-7.0/drivers/usb/core/*'
```

Streaming and extracting only the paths in the walk of shame gives **4.3 MB**
instead of a 1.5 GB tree. The top-level directory is `linux-7.0/`, not
`linux-7.0.0/`.

**The Ubuntu delta is not optional.** It patches the files this investigation
cares about most:

```console
$ curl -s $base/linux_7.0.0-30.30.diff.gz | zcat | grep '^+++ ' | grep bluetooth
```

| file | hunks in the Ubuntu delta |
|---|---|
| `drivers/bluetooth/hci_qca.c` | 11 |
| `net/bluetooth/hci_sync.c` | 9 |
| `net/bluetooth/hci_event.c` | 8 |
| `net/bluetooth/hci_conn.c` | 4 |
| `drivers/bluetooth/btusb.c` | 4 |
| `net/bluetooth/sco.c` | (patched) |

Apply it — 28 files, zero rejects:

```console
$ curl -s $base/linux_7.0.0-30.30.diff.gz | zcat > ubuntu.diff
$ # keep only hunks for paths you extracted, then:
$ cd linux-7.0 && patch -p1 -i ../bt-subset.diff
```

### The version gap, stated plainly

The machine runs **`7.0.0-28-generic`**. The archive currently carries
`-14.14`, `-30.30` and `-31.31`; **`-28` is superseded and gone**, and Launchpad
(which keeps superseded builds) is one of the 403 hosts. So kernel readings here
are against `-30`, one ABI bump *after* the machine. Anything that turns on a
specific kernel line must say which build it was read in.

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
- the exact `-28` kernel build, unless a Launchpad-reachable network fetches it;
- `-0ubuntu5.5` amd64 debug symbols, which do not exist anywhere;
- **anything about the GNOME layer**, which this project captures no logs from at
  all — see [`source-map.md`](source-map.md).

## 7. Where the downloads go

Into a scratch directory outside the repository. **Source trees, `.deb`s and
`.ddeb`s are never committed** — they are large, they are not ours, and
`devtools/repo-scan` refuses non-text files by content for good reason. Findings
come back as text in `reviews/`; the fetch commands above are the reproduction.
