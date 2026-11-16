
### mixed-25

| query | stock wall s | patched wall s | speed-up | stock cpu s | patched cpu s | output (lines or bytes) | exit stock / patched | cap hit |
|---|---|---|---|---|---|---|---|---|
| -b (newest boot) | 13.98 | 4.72 | 3.0x | 14.1 | 4.8 | 630000 (same) | 0 / 0 | no |
| -k -b all | 1.01 | 0.44 | - | 1.0 | 0.3 | 30553 (same) | 0 / 0 | no |
| apport: --quiet -b -a --system | 7.34 | 2.53 | 2.9x | 7.4 | 2.6 | 480000 (same) | 0 / 0 | no |
| sos: --disk-usage | 0.01 | 0.01 | - | 0.0 | 0.0 | 1 (same) | 0 / 0 | no |
| sos: --list-boots | 0.01 | 0.02 | - | 0.0 | 0.0 | 3 (same) | 0 / 0 | no |
| sos full: --no-pager --reverse (first 100 MB) | 31.37 | 5.46 | 5.7x | 31.7 | 5.7 | 104857600 (same) | 141 / 141 | no |
| sos this boot: --no-pager --boot --reverse (first 100 MB) | 13.93 | 4.33 | 3.2x | 14.2 | 4.6 | 104857600 (same) | 141 / 141 | no |
| sos last boot: --no-pager --boot -1 --reverse (first 100 MB) | 9.29 | 3.13 | 3.0x | 9.5 | 3.2 | 69854630 (same) | 0 / 0 | no |
| -b all (full read) | 42.85 | 8.33 | 5.1x | 43.1 | 8.5 | 1038001 (same) | 0 / 0 | no |

### sys-25

| query | stock wall s | patched wall s | speed-up | stock cpu s | patched cpu s | output (lines or bytes) | exit stock / patched | cap hit |
|---|---|---|---|---|---|---|---|---|
| -b (newest boot) | 11.43 | 3.51 | 3.3x | 11.6 | 3.5 | 480000 (same) | 0 / 0 | no |
| -k -b all | 2.71 | 1.10 | 2.5x | 2.7 | 0.6 | 47697 (same) | 0 / 0 | no |
| apport: --quiet -b -a --system | 10.77 | 2.53 | 4.3x | 10.9 | 2.6 | 480000 (same) | 0 / 0 | no |
| sos: --disk-usage | 0.01 | 0.01 | - | 0.0 | 0.0 | 1 (same) | 0 / 0 | no |
| sos: --list-boots | 0.01 | 0.03 | - | 0.0 | 0.0 | 4 (same) | 0 / 0 | no |
| sos full: --no-pager --reverse (first 100 MB) | 39.03 | 5.90 | 6.6x | 39.4 | 6.2 | 104857600 (same) | 141 / 141 | no |
| sos this boot: --no-pager --boot --reverse (first 100 MB) | 11.26 | 3.40 | 3.3x | 11.5 | 3.6 | 81675309 (same) | 0 / 0 | no |
| sos last boot: --no-pager --boot -1 --reverse (first 100 MB) | 11.37 | 3.71 | 3.1x | 11.6 | 3.7 | 81666085 (same) | 0 / 0 | no |
| -b all (full read) | 54.56 | 10.51 | 5.2x | 54.9 | 10.8 | 1200002 (same) | 0 / 0 | no |

### mixed-50

| query | stock wall s | patched wall s | speed-up | stock cpu s | patched cpu s | output (lines or bytes) | exit stock / patched | cap hit |
|---|---|---|---|---|---|---|---|---|
| -b (newest boot) | 24.55 | 5.13 | 4.8x | 24.7 | 5.1 | 630000 (same) | 0 / 0 | no |
| -k -b all | 4.64 | 1.61 | 2.9x | 4.7 | 0.8 | 62993 (same) | 0 / 0 | no |
| apport: --quiet -b -a --system | 13.83 | 2.61 | 5.3x | 14.0 | 2.7 | 480000 (same) | 0 / 0 | no |
| sos: --disk-usage | 0.01 | 0.01 | - | 0.0 | 0.0 | 1 (same) | 0 / 0 | no |
| sos: --list-boots | 0.03 | 0.08 | - | 0.0 | 0.0 | 5 (same) | 0 / 0 | no |
| sos full: --no-pager --reverse (first 100 MB) | 89.78 | 9.29 | 9.7x | 90.2 | 9.6 | 104857600 (same) | 141 / 141 | no |
| sos this boot: --no-pager --boot --reverse (first 100 MB) | 23.84 | 4.72 | 5.1x | 24.2 | 5.0 | 104857600 (same) | 141 / 141 | no |
| sos last boot: --no-pager --boot -1 --reverse (first 100 MB) | 23.73 | 5.44 | 4.4x | 24.1 | 5.5 | 104857600 (same) | 141 / 141 | no |
| -b all (full read) | 195.39 | 24.24 | 8.1x | 196.0 | 24.7 | 2094003 (same) | 0 / 0 | no |

### sys-50

| query | stock wall s | patched wall s | speed-up | stock cpu s | patched cpu s | output (lines or bytes) | exit stock / patched | cap hit |
|---|---|---|---|---|---|---|---|---|
| -b (newest boot) | 19.35 | 4.01 | 4.8x | 19.5 | 3.9 | 480000 (same) | 0 / 0 | no |
| -k -b all | 9.99 | 2.69 | 3.7x | 10.0 | 1.6 | 95837 (same) | 0 / 0 | no |
| apport: --quiet -b -a --system | 18.59 | 2.90 | 6.4x | 18.7 | 3.0 | 480000 (same) | 0 / 0 | no |
| sos: --disk-usage | 0.01 | 0.01 | - | 0.0 | 0.0 | 1 (same) | 0 / 0 | no |
| sos: --list-boots | 0.03 | 0.10 | - | 0.0 | 0.1 | 6 (same) | 0 / 0 | no |
| sos full: --no-pager --reverse (first 100 MB) | 102.86 | 10.94 | 9.4x | 103.2 | 10.3 | 104857600 (same) | 141 / 141 | no |
| sos this boot: --no-pager --boot --reverse (first 100 MB) | 23.89 | 4.16 | 5.7x | 24.2 | 4.4 | 81675309 (same) | 0 / 0 | no |
| sos last boot: --no-pager --boot -1 --reverse (first 100 MB) | 20.03 | 3.71 | 5.4x | 20.3 | 3.9 | 81666085 (same) | 0 / 0 | no |
| -b all (full read) | 249.61 | 30.17 | 8.3x | 250.0 | 30.5 | 2400004 (same) | 0 / 0 | no |

### mixed-100

| query | stock wall s | patched wall s | speed-up | stock cpu s | patched cpu s | output (lines or bytes) | exit stock / patched | cap hit |
|---|---|---|---|---|---|---|---|---|
| -b (newest boot) | 47.45 | 6.54 | 7.3x | 47.6 | 6.4 | 630000 (same) | 0 / 0 | no |
| -k -b all | 20.22 | 3.92 | 5.2x | 20.2 | 2.5 | 126439 (same) | 0 / 0 | no |
| apport: --quiet -b -a --system | 23.61 | 2.91 | 8.1x | 23.7 | 3.0 | 480000 (same) | 0 / 0 | no |
| sos: --disk-usage | 0.01 | 0.01 | - | 0.0 | 0.0 | 1 (same) | 0 / 0 | no |
| sos: --list-boots | 0.06 | 0.24 | - | 0.1 | 0.1 | 8 (same) | 0 / 0 | no |
| sos full: --no-pager --reverse (first 100 MB) | 220.20 | 19.59 | 11.2x | 220.4 | 19.9 | 104857600 (same) | 141 / 141 | no |
| sos this boot: --no-pager --boot --reverse (first 100 MB) | 48.78 | 7.13 | 6.8x | 49.1 | 7.4 | 104857600 (same) | 141 / 141 | no |
| sos last boot: --no-pager --boot -1 --reverse (first 100 MB) | 48.66 | 7.62 | 6.4x | 49.0 | 7.7 | 104857600 (same) | 141 / 141 | no |
| -b all (full read) | 907.79 | 83.75 | 10.8x | 908.4 | 84.5 | 4188006 (same) | 0 / 0 | no |

### sys-100

| query | stock wall s | patched wall s | speed-up | stock cpu s | patched cpu s | output (lines or bytes) | exit stock / patched | cap hit |
|---|---|---|---|---|---|---|---|---|
| -b (newest boot) | 37.53 | 4.64 | 8.1x | 37.7 | 4.5 | 480000 (same) | 0 / 0 | no |
| -k -b all | 43.87 | 7.90 | 5.6x | 44.0 | 5.5 | 191997 (same) | 0 / 0 | no |
| apport: --quiet -b -a --system | 36.58 | 3.39 | 10.8x | 36.8 | 3.5 | 480000 (same) | 0 / 0 | no |
| sos: --disk-usage | 0.01 | 0.01 | - | 0.0 | 0.0 | 1 (same) | 0 / 0 | no |
| sos: --list-boots | 0.08 | 0.35 | - | 0.1 | 0.2 | 11 (same) | 0 / 0 | no |
| sos full: --no-pager --reverse (first 100 MB) | 233.77 | 19.63 | 11.9x | 234.3 | 19.9 | 104857600 (same) | 141 / 141 | no |
| sos this boot: --no-pager --boot --reverse (first 100 MB) | 37.87 | 4.34 | 8.7x | 38.2 | 4.6 | 81675309 (same) | 0 / 0 | no |
| sos last boot: --no-pager --boot -1 --reverse (first 100 MB) | 37.87 | 4.40 | 8.6x | 38.2 | 4.6 | 81666085 (same) | 0 / 0 | no |
| -b all (full read) | 1098.30 | 93.11 | 11.8x | 1100.0 | 94.2 | 4800009 (same) | 0 / 0 | no |
