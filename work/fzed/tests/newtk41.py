# FZED41O: a finished recording keeps nothing from the voice's last sample: mode NORMAL, sustain / end loops off,
# all 8 loops on the new take's start .. end, Stretch's saved state cleared.   python3 newtk41.py BUILD
import os, sys
T = os.path.dirname(os.path.abspath(__file__))
sys.argv = [sys.argv[0], sys.argv[1]]
exec(open(os.path.join(T, 'ext41.py')).read().split('ok = True')[0])
ok = True
def check(c_, msg):
    global ok
    print(('PASS ' if c_ else 'FAIL ') + msg); ok = ok and c_
g = boot(); c = g['c']; EV = c.rd16(0xe04)
d32 = lambda a: c.rd16(a) | (c.rd16(a + 2) << 16)
for i in range(8):                          # an old sample's loops (as Stretch or CHOP leave them)
    c.wr16(EV + 0x14 + 4 * i, 0x7000 + i); c.wr16(EV + 0x16 + 4 * i, 0x0005)
    c.wr16(EV + 0x34 + 4 * i, 0x7100 + i); c.wr16(EV + 0x36 + 4 * i, 0x0005)
c.wr16(EV + 0x12, 0x0300); c.m[0x83FF] = 0x80; c.m[0x801D] = 1
g['midi'](c, 0xb0, 106, 127); g['run'](c, g['u'], 300000)
check(c.m[0x8010] == 1, 'armed (state %d)' % c.m[0x8010])
g['midi'](c, 0xb0, 107, 127); g['run'](c, g['u'], 1000000); g['midi'](c, 0xb0, 109, 127); g['run'](c, g['u'], 1000000)
st, en = d32(EV + 8), d32(EV + 0xc)
check(c.m[0x8010] == 4, 'recording done (state %d)' % c.m[0x8010])
check(c.rd16(EV + 0x10) == 0x1d7, 'mode NORMAL (%04x)' % c.rd16(EV + 0x10))
check(c.rd16(EV + 0x12) == 0x0808, 'sustain / end loops off (%04x)' % c.rd16(EV + 0x12))
lp = [(d32(EV + 0x14 + 4 * i), d32(EV + 0x34 + 4 * i)) for i in range(8)]
check(all(a == st and b == en for a, b in lp), 'all 8 loops on the new take (%x .. %x): %s' % (st, en, [(hex(a), hex(b)) for a, b in lp[:2]]))
check(c.m[0x83FF] & 0x80 == 0 and c.m[0x801D] == 0, 'Stretch off and its moved start forgotten')
print('ALL PASS' if ok else 'SOME FAIL')
