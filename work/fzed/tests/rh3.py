# RH3: after a chop, building a wavetable or loading a preset wave lets the chop's slices go (the keys play the edit
# voice again, as VOICE SELECT); VOICE PICK's preview and VOICE SELECT's line also go to the Gills as STATUS OUT text.
#   python3 rh3.py BUILD   (a folder holding fzedflat.bin and fzed.map)
import os, sys
os.environ['FZTIMER'] = '1'
T = os.path.dirname(os.path.abspath(__file__))
sys.argv = [sys.argv[0], sys.argv[1]]
exec(open(os.path.join(T, 'ext41.py')).read().split('ok = True')[0])
ok = True
def check(c_, msg):
    global ok
    print(('PASS ' if c_ else 'FAIL ') + msg); ok = ok and c_
g = boot(); c = g['c']
MP = {}
for l in open(os.path.join(sys.argv[1], 'fzed.map')):
    p = l.split()
    if len(p) == 3:
        try: MP[p[2]] = int(p[0], 16)
        except ValueError: pass
CHPLAY = 0x81F2
def chopplay():                     # as CHON: the keys play a chop bank
    c.m[CHPLAY] = 1; c.wr16(0xdfe, 0x0e08); c.wr16(0xe00, 0)
EV = c.rd16(0xe04); c.wr16(EV + 0x10, 0)
chopplay()
for n, v in zip((113, 114, 115, 116), (3 * 32 + 8, 0, 0, 127)): cc(g, n, v)
fzed(g, 19, 32); render(g)
check(c.m[CHPLAY] == 0 and c.rd16(0xdfe) == 0xffff, 'WAVETABLE after a chop: the chop let go, the keys play the table (CHPLAY %d, DFE %04X)' % (c.m[CHPLAY], c.rd16(0xdfe)))
chopplay(); bk = 0x83C2; c.m[bk] = 1
render(g)
check(c.m[CHPLAY] == 1, 'in bank mode the table leaves the bank alone (CHPLAY %d)' % c.m[CHPLAY])
c.m[bk] = 0
g2 = boot(); c2 = g2['c']; E2 = c2.rd16(0xe04); c2.wr16(E2 + 0x10, 0)   # an empty edit voice: the wave gets its memory
c2.m[CHPLAY] = 1; c2.wr16(0xdfe, 0x0e08)
cc(g2, 111, 11); cc(g2, 9, 0); cc(g2, 9, 127); g2['run'](c2, g2['u'], 3_000_000)
lcd = [x[2] for x in c2.log if x[0] == 'lcd'][-1:]
check(c2.m[CHPLAY] == 0 and c2.rd16(0xdfe) == 0xffff, 'preset WAVE after a chop: the chop let go (CHPLAY %d, DFE %04X) %r' % (c2.m[CHPLAY], c2.rd16(0xdfe), lcd))
c.ports[0xd2] = 1
fzed(g, 24, 127); g['run'](c, g['u'], 3_000_000)
text = lambda: ''.join(chr(a[2]) if a[2] else '|' for f, a in c.api if f == 0x33 and a[1] == 9)
c.api.clear(); fzed(g, 11, 127); g['run'](c, g['u'], 3_000_000)
check(text().startswith('>') and text().endswith('|'), 'VOICE PICK: the preview goes to the Gills as text: %r' % text())
c.api.clear(); fzed(g, 12, 127); g['run'](c, g['u'], 3_000_000)
check(text().startswith('V'), 'VOICE SELECT: the new edit voice line goes too: %r' % text())
print('ALL PASS' if ok else 'SOME FAIL')
