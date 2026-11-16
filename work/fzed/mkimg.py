# python3 mkimg.py <base FZ disk image> <perf40nflat.bin> <out.img>
# Puts the 34 KB program at sector 17 (byte 17408, sectors 17-50; 44-45 = the capture overlay, 46-49 = the tools
# overlays, 50 = the wave overlay), marks sectors 32-50 used and names the program FZED. Any earlier PERF image works as the base.
import sys
img = bytearray(open(sys.argv[1], 'rb').read()); f = open(sys.argv[2], 'rb').read()
assert len(f) == 34 * 1024
for sec in (46, 47, 48, 49, 50):
    assert set(img[sec * 1024:(sec + 1) * 1024]) <= {0x5a} or img[132 + (sec - 32) // 8] & (1 << (sec % 8)), 'sector %d holds something on the base disk' % sec
img[17408:17408 + len(f)] = f
img[132] = 0xff; img[133] = 0xff; img[134] |= 0x07
img[1040:1052] = b'FZED        '   # the program name the FZ lists and shows (FZED40N, PERF40N before)
assert f[(46 - 17) * 1024 - 2:(46 - 17) * 1024] == b'\x9e\xca'   # capture overlay signature
for sec in (46, 47, 48, 49, 50):
    o = (sec - 17) * 1024
    assert f[o:o + 2] == bytes([sec, 0x40]) and f[o + 0x3be:o + 0x3c0] == bytes([sec, 0x40]), 'overlay %d signatures' % sec
open(sys.argv[3], 'wb').write(img)
