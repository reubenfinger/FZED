# python3 mkimg.py <base FZ disk image> <perf40nflat.bin> <out.img>
# Puts the 33 KB program at sector 17 (byte 17408, sectors 17-49; 44-45 = the capture overlay, 46-49 = the tools
# overlays), marks sectors 40-49 used and names the program FZED. Any earlier PERF image works as the base.
import sys
img = bytearray(open(sys.argv[1], 'rb').read()); f = open(sys.argv[2], 'rb').read()
assert len(f) == 33 * 1024
for sec in (46, 47, 48, 49):
    assert set(img[sec * 1024:(sec + 1) * 1024]) <= {0x5a} or img[132 + (sec - 32) // 8] & (1 << (sec % 8)), 'sector %d holds something on the base disk' % sec
img[17408:17408 + len(f)] = f
img[132] = 0xff; img[133] = 0xff; img[134] |= 0x03
img[1040:1052] = b'FZED        '   # the program name the FZ lists and shows (FZED40N, PERF40N before)
assert f[(46 - 17) * 1024 - 2:(46 - 17) * 1024] == b'\x9e\xca'   # capture overlay signature
for sec in (46, 47, 48, 49):
    o = (sec - 17) * 1024
    assert f[o:o + 2] == bytes([sec, 0x40]) and f[o + 0x3be:o + 0x3c0] == bytes([sec, 0x40]), 'tools overlay %d signatures' % sec
open(sys.argv[3], 'wb').write(img)
