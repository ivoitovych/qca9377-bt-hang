import glob
import os
import re

R = '/root/exp/agent-work/u29-g1-gnome-pairing-feedback/runs/edge'
for d in sorted(glob.glob(R + '/*/')):
    name = os.path.basename(d.rstrip('/'))
    if name.startswith('trial'):
        continue
    for ex in sorted(glob.glob(d + '*.exit')):
        tag = os.path.basename(ex)[:-5]
        code = open(ex).read().strip()
        err = open(d + tag + '.stderr.log').read()
        out = open(d + tag + '.stdout.log').read()
        crit = [l.split('**: ', 1)[-1] for l in err.splitlines() if 'CRITICAL' in l or 'assertion' in l or 'Aborted' in l or 'core dumped' in l or 'Segmentation' in l]
        warn = [l.split('**: ', 1)[-1] for l in err.splitlines() if 'Setting up' in l]
        toasts = sorted(set(re.findall(r'HARNESS TOAST after text="([^"]+)"', out)))
        label = re.findall(r'HARNESS ROW after label="(Not Set Up|[^"]*)" visible=1', out)
        summ = re.findall(r'HARNESS SUMMARY after .*', out)
        print('%s | exit=%s | critical=%s | warn=%s | toast=%s | after-labels=%s | %s' % (
            tag if name.endswith('-1') else name + '/' + tag, code, crit, warn, toasts, label[-1:],
            summ[-1].replace('HARNESS SUMMARY after ', '') if summ else ''))
    dbgf = d + 'agent-debug.txt'
    if os.path.exists(dbgf):
        print('   agent-debug:', open(dbgf).read().replace('\n', ' / '))
