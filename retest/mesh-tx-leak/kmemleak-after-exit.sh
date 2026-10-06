#!/bin/sh
# Guest-side: run a kmemleak scenario without scanning, then scan from
# this shell after the reproducer process has exited (plain scans, no
# slab shrinking), five rounds 6 s apart.
# Usage (as the test-runner command):
#   kmemleak-after-exit.sh <mesh-leak-check> <enetdown|enomem|enodev> <legacy|ext>
# Exits non-zero if the reproducer fails or kmemleak cannot be scanned.
R=$1; CASE=$2; ADV=$3
K=/sys/kernel/debug/kmemleak

"$R" "kmemleak-$CASE" "$ADV" noscan
st=$?
echo "reproducer exited with status $st"
[ $st -eq 0 ] || exit $st

for round in 1 2 3 4 5; do
	sleep 6
	echo scan > $K || { echo "ERROR: kmemleak scan failed"; exit 2; }
	[ -r $K ] || { echo "ERROR: cannot read $K"; exit 2; }
	awk -v r=$round -v c=$CASE '
		/^unreferenced object/ { n++; m = s = 0 }
		/mgmt_mesh_add/ && !m { mesh++; m = 1 }
		/sk_prot_alloc|hci_sock_create/ && !s { sk++; s = 1 }
		END { printf "RESULT %s kmemleak round=%d scan=after_exit " \
			"unreferenced=%d from_mgmt_mesh_add=%d " \
			"from_hci_sock_create=%d\n", c, r, n, mesh, sk }' $K ||
		{ echo "ERROR: cannot parse $K"; exit 2; }
done
sed 's/^/KMEMLEAK /' $K || exit 2
exit 0
