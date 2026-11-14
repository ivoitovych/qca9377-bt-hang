#!/usr/bin/env python3
# destroy-lock-scan.py <tree>: for every destroy-style callback (hdev, void *data, int err) in net/bluetooth,
# report whether hci_dev_lock() (or mgmt_pending lock) is reached before an -ECANCELED early return.
import re, sys, glob, os
tree = sys.argv[1]
sig = re.compile(r'^(?:static\s+)?void\s+(\w+)\(struct hci_dev \*hdev,\s*void \*(?:data|_data),\s*int err\)\s*\n\{', re.M)
for path in sorted(glob.glob(os.path.join(tree, 'net/bluetooth/*.c'))):
    src = open(path, errors='replace').read()
    for m in sig.finditer(src):
        start = m.end()
        end = src.find('\n}\n', start)
        body = src[start:end]
        lock = body.find('hci_dev_lock')
        canc = body.find('ECANCELED')
        if lock < 0:
            verdict = 'no hci_dev_lock'
        elif canc < 0:
            verdict = 'LOCK, no ECANCELED check'
        elif canc < lock:
            verdict = 'ECANCELED check first'
        else:
            verdict = 'LOCK BEFORE ECANCELED check'
        print('%-28s %-44s %s' % (os.path.basename(path), m.group(1), verdict))
