#!/bin/sh
# Full edge matrix. Output: runs/edge/<build>-<scenario>-<error>/ and runs/edge/<same>.log
S=/root/exp/agent-work/u29-g1-gnome-pairing-feedback/scripts/run-edge.sh
for b in master mr137; do
  for e in AuthenticationFailed AuthenticationRejected; do
    $S $b edge/$b-remove-$e remove $e 3
  done
  $S $b edge/$b-peer-AuthenticationCanceled peer AuthenticationCanceled 1
  for e in AuthenticationCanceled AuthenticationFailed AuthenticationRejected; do
    $S $b edge/$b-cancel-$e cancel $e 1
  done
done
