"""Write the bundle's quilt patches (DEP-3 headers) into patches/ and the series fragment.
Sources are the four dossiers' prepared files; only headers are rewritten, the diffs are carried unchanged."""
import os, re, sys
R = "/root/exp/qca9377-bt-hang/contributions/"
OUT = "/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle/patches/"
os.makedirs(OUT, exist_ok=True)
DATE = "2026-11-14"
BUG = "https://bugs.launchpad.net/ubuntu/+source/bluez/+bug/"
U12 = R + "CO-03-bluez-u12-backport/backport/debian-patches-3patch/"
DEBDIFF = R + "CO-11-small-btmon-and-flaky-test/ubuntu/ready-20261102/bluez_5.72-0ubuntu5.8_5.72-0ubuntu5.9.debdiff"
U23 = R + "CO-37-bluez-media-endpoint-exit-uaf/work/patches/5.72-3-20261102/"
U24 = R + "CO-37-bluez-media-endpoint-exit-uaf/work/patches/5.72-discovery/"
CO40 = "/root/exp/agent-work/u29-t1-a2dp-backport/src/upstream-patch/0001-a2dp-Fix-connection-error-message.patch"

def diff_part(text):
    """the unified diff of a git format-patch or DEP-3 file, without signature and base-commit trailer"""
    i = text.index("\ndiff --git ") + 1 if "\ndiff --git " in text else text.index("\n--- a/") + 1
    d = text[i:]
    d = re.split(r"\n(base-commit: [0-9a-f]+\n)?-- \n[0-9.]+\n*$", d)[0].rstrip("\n") + "\n"
    return d

def write(name, header, diff):
    open(OUT + name, "w").write(header.rstrip("\n") + "\n---\n" + diff)
    print("wrote", name)

series = []

# 1,2: btmon (CO-11a): the two patches of the 2026-11-02 debdiff, headers updated
dd = open(DEBDIFF).read()
for name in ("monitor-Fix-crash-due-to-negative-max_len.patch", "monitor-clamp-max_len-in-print_packet.patch"):
    m = re.search(r"^\+\+\+ bluez-5.72/debian/patches/" + re.escape(name) + r"\t.*\n@@ -0,0 \+1,(\d+) @@\n", dd, re.M)
    n = int(m.group(1))
    body = dd[m.end():].split("\n")[:n]
    text = "\n".join(l[1:] for l in body) + "\n"
    head, rest = text.split("\n---\n", 1)
    head = re.sub(r"Bug-Ubuntu: .*", "Bug-Ubuntu: " + BUG + "<LP-BTMON>", head)
    head = re.sub(r"Last-Update: .*", "Last-Update: " + DATE, head)
    write(name, head, rest)
    series.append(name)

# 3: U24 discovery_found
t = open(U24 + "0001-adapter-clear-discovery_found-list-before-discovery_.patch").read()
h = f"""Description: adapter: clear discovery_found list before discovery_cleanup()
 discovery_cleanup() tries to reset the RSSI of the devices in the
 adapter->discovery_found list. When it is called from adapter_remove(), the
 list holds only stale pointers because the devices are already freed, which
 is a use-after-free when bluetoothd exits (seen with AddressSanitizer at
 src/device.c, device_set_rssi_with_delta()). Free the list in
 adapter_remove() before discovery_cleanup().
Author: Pauli Virtanen <pav@iki.fi>
Origin: upstream, https://git.kernel.org/pub/scm/bluetooth/bluez.git/commit/?id=7e3212fa233edbdcfd69f93e2a7418819172c599
Applied-Upstream: 5.88, commit:7e3212fa233edbdcfd69f93e2a7418819172c599
Bug-Ubuntu: {BUG}<LP-U24>
Forwarded: not-needed
Last-Update: {DATE}"""
write("adapter-clear-discovery_found-list-before-discovery_cleanup.patch", h, diff_part(t))
series.append("adapter-clear-discovery_found-list-before-discovery_cleanup.patch")

# 4,5,6: U23 (three patches; not upstream)
spec = [
 ("0001-media-Unlink-endpoints-from-their-application-on-rem.patch", "media-Unlink-endpoints-from-their-application-on-removal.patch",
  """Description: media: Unlink endpoints from their application on removal
 Backport for 5.72 of the endpoint part of upstream commit 7482aceece70
 ("profiles/audio: fix UAF on external media service teardown"), with the
 unlinking done before the A2DP SEP is removed. Needed by the next but one
 patch: once path_free() releases the endpoints before freeing the
 applications, app_free() must not find the released endpoints in its queue.
Author: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Origin: backport, https://git.kernel.org/pub/scm/bluetooth/bluez.git/commit/?id=7482aceece7044e688f20f113263b50c21d69fb6
Bug-Ubuntu: """ + BUG + """<LP-U23>
Forwarded: no
Last-Update: """ + DATE),
 ("0002-media-Fix-sending-Release-twice-to-A2DP-endpoints.patch", "media-Fix-sending-Release-twice-to-A2DP-endpoints.patch",
  """Description: media: Fix sending Release twice to A2DP endpoints
 release_endpoint() sends Release to the endpoint and then removes it. For
 an A2DP endpoint this unregisters its SEP, whose destroy callback calls
 release_endpoint() again, which sends a second Release. This happens to
 every A2DP endpoint that path_free() releases, on adapter removal and on
 exit. Mark the endpoint as released once Release is sent.
Author: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Origin: other, written for this update; fixes bd3ca4fdf463 ("Fix possible invalid read/free on media.c")
Bug-Ubuntu: """ + BUG + """<LP-U23>
Forwarded: no
Last-Update: """ + DATE),
 ("0003-media-Fix-use-after-free-releasing-endpoints-on-adap.patch", "media-Fix-use-after-free-releasing-endpoints-on-adapter-removal.patch",
  """Description: media: Fix use-after-free releasing endpoints on adapter removal
 path_free() frees the applications before releasing the endpoints. Freeing
 an application removes its endpoints, and removing an A2DP endpoint whose
 stream is locked by an acquired transport is deferred by a2dp_remove_sep(),
 so the endpoint stays in the adapter's list. release_endpoint() then clears
 its transports, which unlocks the stream; the SEP is unregistered and its
 destroy callback releases and frees the endpoint while clear_endpoint() is
 still iterating over its transports (heap-use-after-free at
 profiles/audio/media.c, clear_endpoint(), seen with AddressSanitizer when
 bluetoothd exits while a sound server streams). Release the endpoints
 first, so that their transports are cleared while their SEPs are still
 registered and the removal is not deferred.
Author: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Origin: other, written for this update; fixes ee0f3c03fb1d ("media: Fix UnregisterApplication")
Bug-Ubuntu: """ + BUG + """<LP-U23>
Forwarded: no
Last-Update: """ + DATE),
]
for src, name, head in spec:
    write(name, head, diff_part(open(U23 + src).read()))
    series.append(name)

# 7,8,9: U12 (the three-patch candidate; add the Bug-Ubuntu line, new Last-Update)
for name in ("transport-Add-transport_a2dp_get_stream-helper.patch",
             "transport-don-t-disconnect-A2DP-if-canceling-Acquire-with-Release.patch",
             "a2dp-don-t-change-setup-sep-when-it-is-reconfiguring.patch"):
    t = open(U12 + name).read()
    t = re.sub(r"^Last-Update: .*$", "Bug-Ubuntu: " + BUG + "<LP-U12>\nLast-Update: " + DATE, t, count=1, flags=re.M)
    open(OUT + name, "w").write(t)
    print("wrote", name)
    series.append(name)

# 10: CO-40
t = open(CO40).read()
h = f"""Description: a2dp: Fix connection error message
 When a headset has dropped the pairing, the A2DP connect fails with
 ECONNREFUSED, which error_to_errno() turned into -EAGAIN, so the D-Bus error
 was br-connection-unknown. Map ECONNREFUSED to itself so that the error is
 br-connection-refused.
Author: Frédéric Danis <frederic.danis@collabora.com>
Origin: upstream, https://git.kernel.org/pub/scm/bluetooth/bluez.git/commit/?id=a6ac17f0e3932d6b07ced87e41fe7a108fe55149
Applied-Upstream: 5.78, commit:a6ac17f0e3932d6b07ced87e41fe7a108fe55149
Bug-Ubuntu: {BUG}<LP-REFUSED>
Forwarded: not-needed
Last-Update: {DATE}"""
write("a2dp-Fix-connection-error-message.patch", h, diff_part(t))
series.append("a2dp-Fix-connection-error-message.patch")

open(OUT + "series.fragment", "w").write("\n".join(series) + "\n")
print("\n".join(series))
