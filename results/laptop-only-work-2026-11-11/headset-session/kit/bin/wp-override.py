#!/usr/bin/env python3
"""User-level override helper for the headset session (run as the desktop user,
never as root).  It reads files under /usr (read only) and writes ONLY below
$HOME/.config.  Nothing here restarts a service; each action prints the one
restart command that makes it take effect.

  wp-override.py status
  wp-override.py install meter        CO-32  WirePlumber policy-node.lua, one line moved
  wp-override.py install hwvol        CO-33/U15  headset microphone volume off for two named headsets
  wp-override.py install noswitch     CO-29  no automatic Handsfree switch for listed applications
  wp-override.py install noswitch-all CO-29  no automatic Handsfree switch at all (broader)
  wp-override.py install onconnect    CO-15  module-switch-on-connect for Bluetooth outputs
  wp-override.py install plugin       CO-19  the rebuilt Bluetooth SPA plugin for WirePlumber only
                                      (a private plugin directory + a systemd user drop-in; no apt)
  wp-override.py remove <name>        removes exactly what install wrote (refuses if the file was edited)

Every installed file starts with a marker line; remove deletes a file only if its
SHA-256 still equals the one recorded at install time.
"""
import difflib
import hashlib
import json
import os
import sys

HOME = os.path.expanduser("~")
CFG = os.path.join(HOME, ".config")
WP = os.path.join(CFG, "wireplumber")
PW = os.path.join(CFG, "pipewire")
REC = os.path.join(CFG, "kit-session-overrides.json")
MARK = "kit-session-override"

SPA_STOCK = "/usr/lib/x86_64-linux-gnu/spa-0.2"
SPA_STOCK_BLUEZ_SHA = "421baed5a6f0e15103a5d1545da7b63556c5332e5181bd0476747d2bb3ed1c3a"  # 1.0.5-1ubuntu3.3
ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "artifacts", "spa-bluez5-1.0.5-1ubuntu3.4")
PRIV = os.path.join(HOME, ".local", "share", "kit-session", "spa-0.2")
DROPIN = os.path.join(CFG, "systemd", "user", "wireplumber.service.d", "91-kit-spa-plugin-dir.conf")

POLICY_NODE = "/usr/share/wireplumber/scripts/policy-node.lua"
POLICY_NODE_SHA = "2425c90523e39b480e10a35b14dd4bcd0e2618e9d0d4ad4359a10340792e2a61"
HWCONF = "/usr/share/spa-0.2/bluez5/bluez-hardware.conf"
HWCONF_SHA = "ec7d6656cba367c4c4187c7e67ed314be1b4d9236d90dbd22731753f2bd15c63"

OLD = """    if skip_this_target == false then
      createLink (si, si_target, can_passthrough, exclusive)
    end
    si_flags[si.id].was_handled = true
"""
NEW = """    if skip_this_target == false then
      createLink (si, si_target, can_passthrough, exclusive)
      si_flags[si.id].was_handled = true
    end
"""

HEADSETS = ["Shure AONIC 50", "MOMENTUM 4"]


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_rec():
    try:
        with open(REC) as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


def save_rec(rec):
    if rec:
        os.makedirs(CFG, exist_ok=True)
        with open(REC, "w") as f:
            json.dump(rec, f, indent=1, sort_keys=True)
    elif os.path.exists(REC):
        os.remove(REC)


def prune(path):
    """remove empty directories upwards, never above $HOME/.config"""
    d = os.path.dirname(path)
    while d.startswith(CFG + os.sep):
        try:
            os.rmdir(d)
        except OSError:
            break
        d = os.path.dirname(d)


def die(msg):
    print("REFUSED: " + msg, file=sys.stderr)
    sys.exit(2)


def build_meter():
    src = open(POLICY_NODE, "rb").read()
    if sha(src) != POLICY_NODE_SHA:
        die("the installed policy-node.lua is not the 0.4.17-1ubuntu4.1 file this kit was built for "
            "(sha256 %s)" % sha(src))
    text = src.decode()
    if text.count(OLD) != 1:
        die("the lines to change were not found exactly once")
    new_text = text.replace(OLD, NEW)
    if not new_text.endswith("\n"):
        new_text += "\n"
    # one log line when the script is loaded, so the journal shows that the override is the file in use
    new_text += 'Log.info("%s: policy-node.lua override is loaded")\n' % MARK
    new = new_text.encode()
    diff = "".join(difflib.unified_diff(text.splitlines(True), new_text.splitlines(True),
                                        "installed policy-node.lua", "override policy-node.lua", n=2))
    return os.path.join(WP, "scripts", "policy-node.lua"), new, diff, "systemctl --user restart wireplumber"


def build_hwvol():
    src = open(HWCONF, "rb").read()
    if sha(src) != HWCONF_SHA:
        die("the installed bluez-hardware.conf is not the file this kit was built for (sha256 %s)" % sha(src))
    text = src.decode()
    anchor = "bluez5.features.device = [\n"
    if text.count(anchor) != 1:
        die("anchor line not found exactly once")
    rules = "".join('    { name = "%s", no-features = [ hw-volume-mic ] },  # %s\n' % (n, MARK)
                    for n in HEADSETS)
    db = text.replace(anchor, anchor + rules)
    if "]==]" in db:
        die("unexpected long-bracket terminator in the table")
    lua = ("-- %s: the shipped hardware table plus %s without microphone hardware volume.\n"
           "-- Remove with: wp-override.py remove hwvol\n"
           'bluez_monitor.properties["bluez5.hardware-database"] = [==[\n%s]==]\n'
           % (MARK, " and ".join(HEADSETS), db))
    diff = "".join('+' + r.lstrip() for r in rules.splitlines(True))
    return (os.path.join(WP, "bluetooth.lua.d", "51-kit-hw-volume-mic-quirk.lua"), lua.encode(),
            "added to the shipped table, first in the device rules:\n" + diff,
            "systemctl --user restart wireplumber")


def build_noswitch(all_):
    if all_:
        body = 'bluetooth_policy.policy["media-role.use-headset-profile"] = false\n'
        what = "no automatic switch to Handsfree for any recording"
    else:
        body = 'bluetooth_policy.policy["media-role.applications"] = {}\n'
        what = "the application list is empty: only streams with media.role Communication still switch"
    lua = "-- %s: %s.\n-- Remove with: wp-override.py remove %s\n%s" % (
        MARK, what, "noswitch-all" if all_ else "noswitch", body)
    return (os.path.join(WP, "policy.lua.d", "51-kit-no-auto-handsfree.lua"), lua.encode(),
            "+" + body, "systemctl --user restart wireplumber")


def build_onconnect():
    conf = ("# %s: a newly connected Bluetooth output becomes the default output.\n"
            "# Remove with: wp-override.py remove onconnect\n"
            "pulse.cmd = [\n"
            '    { cmd = "load-module" args = "module-switch-on-connect blocklist=hdmi|^alsa_|^bluez_input" }\n'
            "]\n" % MARK)
    return (os.path.join(PW, "pipewire-pulse.conf.d", "90-kit-switch-on-connect.conf"), conf.encode(),
            "+pulse.cmd = [ module-switch-on-connect blocklist=hdmi|^alsa_|^bluez_input ]",
            "systemctl --user restart pipewire-pulse")


BUILDERS = {
    "meter": lambda: build_meter(),
    "hwvol": lambda: build_hwvol(),
    "noswitch": lambda: build_noswitch(False),
    "noswitch-all": lambda: build_noswitch(True),
    "onconnect": lambda: build_onconnect(),
}
# names that write the same file may not be installed together
SAME_FILE = {"noswitch": "noswitch-all", "noswitch-all": "noswitch"}


def install_plugin():
    rec = load_rec()
    if "plugin" in rec:
        die("plugin is already installed")
    if os.path.exists(PRIV) or os.path.exists(DROPIN):
        die("%s or %s exists and was not written by this kit" % (PRIV, DROPIN))
    # the artifact files must match their SHA256SUMS
    sums = {}
    for line in open(os.path.join(ART, "SHA256SUMS")):
        h, f = line.split()
        sums[f] = h
    for f, h in sums.items():
        if sha(open(os.path.join(ART, f), "rb").read()) != h:
            die("artifact %s does not match SHA256SUMS" % f)
    stock = os.path.join(SPA_STOCK, "bluez5", "libspa-bluez5.so")
    if sha(open(stock, "rb").read()) != SPA_STOCK_BLUEZ_SHA:
        die("the installed libspa-bluez5.so is not the 1.0.5-1ubuntu3.3 file this plugin was built against")
    os.makedirs(os.path.join(PRIV, "bluez5"))
    for e in sorted(os.listdir(SPA_STOCK)):
        if e != "bluez5":
            os.symlink(os.path.join(SPA_STOCK, e), os.path.join(PRIV, e))
    for f in sorted(sums):
        data = open(os.path.join(ART, f), "rb").read()
        dest = os.path.join(PRIV, "bluez5", f)
        with open(dest, "wb") as fh:
            fh.write(data)
        os.chmod(dest, 0o755)
    # stock bluez5 files that the artifact does not carry stay reachable
    for f in sorted(os.listdir(os.path.join(SPA_STOCK, "bluez5"))):
        if f not in sums:
            os.symlink(os.path.join(SPA_STOCK, "bluez5", f), os.path.join(PRIV, "bluez5", f))
    os.makedirs(os.path.dirname(DROPIN), exist_ok=True)
    text = ("# %s: WirePlumber loads the rebuilt Bluetooth SPA plugin from a private plugin directory.\n"
            "# Remove with: wp-override.py remove plugin\n[Service]\nEnvironment=\"SPA_PLUGIN_DIR=%s\"\n" % (MARK, PRIV))
    with open(DROPIN, "w") as f:
        f.write(text)
    rec["plugin"] = {"path": DROPIN, "sha256": sha(text.encode()), "dir": PRIV}
    save_rec(rec)
    print("installed plugin: %d rebuilt files in %s/bluez5, every other plugin is a link to the stock file" % (
        len(sums), PRIV))
    print("drop-in %s" % DROPIN)
    print("takes effect after: systemctl --user daemon-reload  and then  systemctl --user restart wireplumber")


def remove_plugin():
    rec = load_rec()
    if "plugin" not in rec:
        die("plugin is not installed by this kit")
    r = rec["plugin"]
    cur = open(r["path"], "rb").read() if os.path.exists(r["path"]) else None
    if cur is not None and sha(cur) != r["sha256"]:
        die("%s was edited after install; remove it by hand" % r["path"])
    if cur is not None:
        os.remove(r["path"])
    prune(r["path"])
    d = r["dir"]
    if os.path.isdir(d) and os.path.abspath(d) == os.path.abspath(PRIV):
        for dp, dn, fn in os.walk(d, topdown=False):
            for f in fn:
                os.remove(os.path.join(dp, f))
            for x in dn:
                p = os.path.join(dp, x)
                if os.path.islink(p):
                    os.remove(p)
                else:
                    os.rmdir(p)
        os.rmdir(d)
        try:
            os.rmdir(os.path.dirname(d))   # ~/.local/share/kit-session, only if empty
        except OSError:
            pass
    del rec["plugin"]
    save_rec(rec)
    print("removed plugin (directory %s and drop-in)" % d)
    print("takes effect after: systemctl --user daemon-reload  and then  systemctl --user restart wireplumber")


def install(name):
    if name == "plugin":
        return install_plugin()
    if name not in BUILDERS:
        die("unknown override %r" % name)
    rec = load_rec()
    if name in rec:
        die("%s is already installed (%s)" % (name, rec[name]["path"]))
    other = SAME_FILE.get(name)
    if other and other in rec:
        die("%s is installed and uses the same file; remove it first" % other)
    path, data, shown, restart = BUILDERS[name]()
    if os.path.exists(path):
        die("%s exists and was not written by this kit" % path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)
    rec[name] = {"path": path, "sha256": sha(data)}
    save_rec(rec)
    print("installed %s -> %s" % (name, path))
    print("sha256 %s" % sha(data))
    print("what it changes:\n%s" % shown)
    print("takes effect after: %s" % restart)


def remove(name):
    if name == "plugin":
        return remove_plugin()
    rec = load_rec()
    if name not in rec:
        die("%s is not installed by this kit" % name)
    path = rec[name]["path"]
    try:
        cur = open(path, "rb").read()
    except FileNotFoundError:
        cur = None
    if cur is not None and sha(cur) != rec[name]["sha256"]:
        die("%s was edited after install; remove it by hand" % path)
    if cur is not None:
        os.remove(path)
    prune(path)
    del rec[name]
    save_rec(rec)
    restart = ("systemctl --user restart pipewire-pulse" if name == "onconnect"
               else "systemctl --user restart wireplumber")
    print("removed %s (%s)" % (name, path))
    print("takes effect after: %s" % restart)


def status():
    rec = load_rec()
    print("overrides installed by this kit: %s" % (", ".join(sorted(rec)) or "none"))
    for name, r in sorted(rec.items()):
        try:
            ok = sha(open(r["path"], "rb").read()) == r["sha256"]
            state = "unchanged" if ok else "EDITED"
        except FileNotFoundError:
            state = "MISSING"
        print("  %-13s %s  %s" % (name, state, r["path"]))
    for d in (os.path.join(WP, "scripts"), os.path.join(WP, "bluetooth.lua.d"),
              os.path.join(WP, "policy.lua.d"), os.path.join(PW, "pipewire-pulse.conf.d")):
        if os.path.isdir(d):
            for f in sorted(os.listdir(d)):
                print("  present in %s: %s" % (d, f))
    for p, want in ((POLICY_NODE, POLICY_NODE_SHA), (HWCONF, HWCONF_SHA)):
        try:
            got = sha(open(p, "rb").read())
            print("  shipped %s: %s" % (p, "as expected" if got == want else "DIFFERENT (%s)" % got))
        except FileNotFoundError:
            print("  shipped %s: not found" % p)


def main(argv):
    if os.geteuid() == 0:
        die("run as the desktop user, not as root")
    if len(argv) >= 2 and argv[1] == "status":
        return status()
    if len(argv) == 3 and argv[1] == "install":
        return install(argv[2])
    if len(argv) == 3 and argv[1] == "remove":
        return remove(argv[2])
    print(__doc__)
    sys.exit(1)


main(sys.argv)
