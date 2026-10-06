## control: busy-drain

| Observation | ext | legacy |
|---|---|---|
| A had 3 outstanding handles before B's send | 5/5 | 5/5 |
| A Busy after power-on | 5/5 | 5/5 |
| A has no outstanding handles after B's 1st send | 5/5 | 5/5 |
| Mesh Packet Complete for failed handle 1, never started | 5/5 | 5/5 |
| failed handles 2, 3 started (mesh_send_sync) | 5/5 | 5/5 |
| failed handles 2, 3 data reached controller | 5/5 | 5/5 |
| B's 1st packet started twice | 5/5 | 5/5 |
| A can send again | 5/5 | 5/5 |

## patched: busy-drain

| Observation | ext | legacy |
|---|---|---|
| A had 3 outstanding handles before B's send | 0/5 | 0/5 |
| A Busy after power-on | 0/5 | 0/5 |
| A has no outstanding handles after B's 1st send | 5/5 | 5/5 |
| Mesh Packet Complete for failed handle 1, never started | 0/5 | 0/5 |
| failed handles 2, 3 started (mesh_send_sync) | 0/5 | 0/5 |
| failed handles 2, 3 data reached controller | 0/5 | 0/5 |
| B's 1st packet started twice | 0/5 | 0/5 |
| A can send again | 5/5 | 5/5 |

## diag-control: kmemleak

| Case | Scan | Runs | Request reported | Socket reported | First round |
|---|---|---|---|---|---|
| `-ENETDOWN` | plain, after the reproducer exited | 5 | 5/5 | 0/5 | 2 |
| `-ENETDOWN` | plain, from the running reproducer | 5 | 0/5 | 0/5 | - |
| `-ENETDOWN` | slab caches shrunk, from the running reproducer | 5 | 5/5 | 5/5 | 2 |
| `-ENODEV` | plain, after the reproducer exited | 5 | 5/5 | 0/5 | 2 |
| `-ENODEV` | plain, from the running reproducer | 5 | 0/5 | 0/5 | - |
| `-ENODEV` | slab caches shrunk, from the running reproducer | 5 | 5/5 | 0/5 | 3 |
| `-ENOMEM` | plain, after the reproducer exited | 5 | 5/5 | 5/5 | 2 |
| `-ENOMEM` | plain, from the running reproducer | 5 | 5/5 | 5/5 | 2 |
| `-ENOMEM` | slab caches shrunk, from the running reproducer | 5 | 5/5 | 5/5 | 2 |

## diag-patched: kmemleak

| Case | Scan | Runs | Request reported | Socket reported | First round |
|---|---|---|---|---|---|
| `-ENETDOWN` | plain, after the reproducer exited | 2 | 0/2 | 0/2 | - |
| `-ENETDOWN` | plain, from the running reproducer | 2 | 0/2 | 0/2 | - |
| `-ENETDOWN` | slab caches shrunk, from the running reproducer | 2 | 0/2 | 0/2 | - |
| `-ENODEV` | plain, after the reproducer exited | 2 | 0/2 | 0/2 | - |
| `-ENODEV` | plain, from the running reproducer | 2 | 0/2 | 0/2 | - |
| `-ENODEV` | slab caches shrunk, from the running reproducer | 2 | 0/2 | 0/2 | - |
| `-ENOMEM` | plain, after the reproducer exited | 2 | 0/2 | 0/2 | - |
| `-ENOMEM` | plain, from the running reproducer | 2 | 0/2 | 0/2 | - |
| `-ENOMEM` | slab caches shrunk, from the running reproducer | 2 | 0/2 | 0/2 | - |

