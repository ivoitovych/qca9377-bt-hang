# The real btmon's output, for tests/btmon/render to be checked against

`tests/btmon/render` prints btmon text as btmon 5.72 prints it when its output is not a terminal,
and every btmon stub in `tests/run-tests` pipes its fixture through it. These files hold what the
real btmon printed, so that the suite can check the renderer against the real tool rather than
against a description of it.

| file | what |
|---|---|
| `mkcap.py` | builds two synthetic captures in `bin/bt-capture`'s monitor format, placeholder addresses only (`AA:BB:CC:DD:EE:FF`): `lines.btsnoop` and `priv-open.btsnoop` |
| `lines-80.txt` | `TZ=UTC btmon -T -r lines.btsnoop`, piped: the default width |
| `lines-160.txt` | the same with `--columns=160` |
| `lines-200.txt` | the same with `--columns=200` |
| `priv-open-200.txt` | `TZ=UTC btmon --columns=200 -T -r priv-open.btsnoop` |

`lines.btsnoop` holds one record of each header shape the project's tools read: a New Index, a
non-privileged MGMT Open and an MGMT command, Setup Synchronous Connection, Command Status,
Synchronous Connect Complete, Enhanced Setup Synchronous Connection.

**The btmon**: Ubuntu 24.04's `bluez` 5.72-0ubuntu5.8, the laptop's version, from
`apt-get download bluez`, unpacked and run without installing (2026-10-19). The captures are
not committed (binary captures never are, `devtools/repo-scan`); `mkcap.py` rebuilds them.

**What it showed**, and the suite now pins:
- piped, btmon cuts names to fit 80 columns (`< HCI Command: Se.. (0x01|0x0028) plen 17`), and
  `COLUMNS` makes no difference; only `--columns=N` widens it;
- on `priv-open.btsnoop`, `btmon -T -r` aborts (`*** buffer overflow detected ***: terminated`,
  exit 134, no output) at 79 and 80 columns, and decodes from 81. That is `print_packet`'s
  `max_len` going to -2 (BT-4; `docs/STATUS.md`); with `--columns=200` it decodes.

To regenerate: `python3 mkcap.py <dir>`, then the commands in the table, with that btmon.
