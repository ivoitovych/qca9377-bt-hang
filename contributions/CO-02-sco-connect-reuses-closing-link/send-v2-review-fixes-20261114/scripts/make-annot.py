"""make-annot.py : write proposal/abort-reason-readonce.diff, the one-token annotation change of the audit
(READ_ONCE() on the check at the top of hci_abort_conn()), as a diff against the l7-ab blob of hci_conn.c."""
import subprocess, difflib, os

W = "/root/exp/agent-work/lane7-sco-20261114"
old = subprocess.check_output(["git", "-C", W + "/linux", "show", "l7-ab:net/bluetooth/hci_conn.c"]).decode()
marker = ("\t/* If abort_reason has already been set it means the connection is\n"
          "\t * already being aborted so don't attempt to overwrite it.\n"
          "\t */\n"
          "\tif (conn->abort_reason)\n")
assert old.count(marker) == 1
new = old.replace(marker, marker.replace("if (conn->abort_reason)", "if (READ_ONCE(conn->abort_reason))"))
diff = difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                            "a/net/bluetooth/hci_conn.c", "b/net/bluetooth/hci_conn.c", n=3)
os.makedirs(W + "/proposal", exist_ok=True)
with open(W + "/proposal/abort-reason-readonce.diff", "w") as f:
    f.write("diff --git a/net/bluetooth/hci_conn.c b/net/bluetooth/hci_conn.c\n")
    f.writelines(diff)
print("written")
