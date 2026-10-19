# Two synthetic btsnoop captures (monitor format, as bin/bt-capture writes it), placeholder
# addresses only, for the real btmon to decode:
#   lines.btsnoop       the header lines the project's tools read; decodes at any width
#   priv-open.btsnoop   one privileged MGMT Open, on which btmon 5.72 -T aborts below 81 columns
# Usage: python3 mkcap.py <directory>
import os, struct, sys, time
OFF = 0x00E03AB44A676000 - 946684800 * 1000000   # bt-capture: (unix - UNIX_2000) * 1e6 + offset
def rec(t_us, index, opcode, data):
    return struct.pack('>IIIIq', len(data), len(data), (index << 16) | opcode, 0, OFF + t_us) + data
t0 = int(time.mktime((2026, 10, 17, 1, 4, 57, 0, 0, -1))) * 1000000
bd = bytes.fromhex('ffeeddccbbaa')                     # AA:BB:CC:DD:EE:FF
r = [b'btsnoop\x00' + struct.pack('>II', 1, 2001)]
r.append(rec(t0, 0, 0, bytes([0, 1]) + bd + b'hci0\x00\x00\x00\x00'))                       # New Index
def ctrl_open(t, cookie, flags, comm):
    c = comm.encode() + b'\x00'
    return rec(t, 0, 14, struct.pack('<IHBHIB', cookie, 2, 1, 22, flags, len(c)) + c)      # MGMT Open
r.append(ctrl_open(t0 + 300, 2, 0, 'bt-state'))
r.append(rec(t0 + 400, 0, 16, struct.pack('<IH', 2, 0x0005) + b'\x01'))                    # MGMT Command: Set Powered
p = struct.pack('<HIIHHBH', 0x0003, 8000, 8000, 0x000d, 0x0060, 0x02, 0x0380)
r.append(rec(t0 + 1000, 0, 2, struct.pack('<HB', 0x0428, len(p)) + p))                     # Setup Synchronous Connection
r.append(rec(t0 + 1100, 0, 3, struct.pack('<BBBBH', 0x0f, 4, 0x00, 1, 0x0428)))            # Command Status
e = struct.pack('<BH6sBBBHHB', 0x00, 0x0006, bd, 0x02, 0x0c, 0x06, 60, 60, 0x02)
r.append(rec(t0 + 50000, 0, 3, struct.pack('<BB', 0x2c, len(e)) + e))                      # Synchronous Connect Complete
ep = bytes(59)
r.append(rec(t0 + 60000, 0, 2, struct.pack('<HB', 0x043d, len(ep)) + ep))                  # Enhanced Setup Synchronous Connection
out = sys.argv[1]
open(os.path.join(out, 'lines.btsnoop'), 'wb').write(b''.join(r))
open(os.path.join(out, 'priv-open.btsnoop'), 'wb').write(r[0] + r[1] + ctrl_open(t0 + 100, 1, 1, 'bluetoothctl'))
