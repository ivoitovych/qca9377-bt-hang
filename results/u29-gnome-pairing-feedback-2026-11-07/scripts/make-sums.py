import hashlib
import os

A = '/root/exp/agent-work/u29-g1-gnome-pairing-feedback'
lines = []
for top in ('docker', 'scripts', 'tests', 'runs'):
    for d, _, fs in os.walk(os.path.join(A, top)):
        for f in sorted(fs):
            p = os.path.join(d, f)
            lines.append('%s  %s' % (hashlib.sha256(open(p, 'rb').read()).hexdigest(),
                                      os.path.relpath(p, A)))
open(os.path.join(A, 'SHA256SUMS'), 'w').write('\n'.join(sorted(lines, key=lambda l: l.split('  ')[1])) + '\n')
