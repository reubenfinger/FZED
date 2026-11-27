# RH7: FZED 35 UNISON (OFF / 2 / 4 / 8 = MONO) and FZED 36 DETUNE (the unison overlay, sector 57), UNSYNC in the main loop.
#   python3 unison.py BUILD   (a folder holding fzedflat.bin and fzed.map)
# Checks: the FZED bank gets one area a layer on this channel, generator masks 55h/AAh (2), 11h.. (4), 01h.. (8); the
# copies are the edit voice but for the pitch (+ their detune) and stay so after an edit (main loop); DETUNE spreads
# +-j x DETUNE / (N / 2); DUAL takes the picked voice as layer 2 and leaves it alone; OFF empties the copies, removes
# the areas and leaves the edit voice and the picked voice as they were.
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
lcd = lambda: [x[2].strip() for x in c.log if x[0] == 'lcd']
r16 = lambda a: c.m[a] | c.m[a + 1] << 8
def s16(v): return v - 0x10000 if v & 0x8000 else v
V = lambda n: 0x2288 + n * 0xc0
UNN, UNBK, UNCH, UNE, UNSV = (MAP[k] for k in ('UNN', 'UNBK', 'UNCH', 'UNE', 'UNSV')); VPICK = 0x8004
def areas():
    B = r16(UNBK); n = r16(B)
    return B, [(i, c.m[B + 0x182 + i], r16(B + 0x202 + 2 * i)) for i in range(n) if c.m[B + 0x142 + i] == c.m[UNCH]]
def loop(): g['run'](c, g['u'], 400000)

nsound = lambda: sum(r16(V(n) + 0x10) != 0 for n in range(64))
n0 = nsound()
c.log.clear(); fzed(g, 35, 40); loop()
B, a = areas(); E = r16(UNE)
check(c.m[UNN] == 2 and [x[1] for x in a] == [0x55, 0xaa] and a[0][2] == E, 'UNISON 2: two areas, generators 55h / AAh, layer 1 the edit voice (%s, %s)' % ([(m, hex(p)) for _, m, p in a], lcd()[-2:]))
C = a[1][2]
check(bytes(c.m[C:C + 0x74]) == bytes(c.m[E:E + 0x74]) and bytes(c.m[C + 0x76:C + 0xb2]) == bytes(c.m[E + 0x76:E + 0xb2]) and r16(C + 0x74) == r16(E + 0x74), 'the copy is the edit voice (DETUNE 0: same pitch)')
check(any('UNISON 2' in x for x in lcd()), 'message UNISON 2 (%s)' % lcd()[-3:])

fzed(g, 36, 100); loop()
check(s16(r16(C + 0xbe)) == 100 and r16(C + 0x74) == (r16(E + 0x74) + 100) & 0xffff, 'DETUNE 100: the copy %d fine steps up (pitch %04X vs %04X)' % (s16(r16(C + 0xbe)), r16(C + 0x74), r16(E + 0x74)))
c.m[E + 0x76] ^= 0x5a; c.m[E + 0x77] ^= 0x21; loop()
check(c.m[C + 0x76] == c.m[E + 0x76] and c.m[C + 0x77] == c.m[E + 0x77] and r16(C + 0x74) == (r16(E + 0x74) + 100) & 0xffff, 'an edit to the edit voice (DCF, Q) reaches the copy in the main loop, detune kept')

fzed(g, 35, 127); loop()
B, a = areas()
cp = [p for _, _, p in a if p != E]
dt = [s16(r16(p + 0xbe)) for p in cp]
check(c.m[UNN] == 8 and [x[1] for x in a] == [1 << i for i in range(8)] and a[0][2] == E, 'UNISON 8 (MONO): eight areas, one generator each (%s)' % [hex(x[1]) for x in a])
check(dt == [25, -25, 50, -50, 75, -75, 100] and all(r16(p + 0x74) == (r16(E + 0x74) + d) & 0xffff for p, d in zip(cp, dt)), 'DETUNE spread +-25/50/75/100: %s' % dt)
check(nsound() == n0 + 7, 'the UNISON 2 copy went when 8 replaced it: 7 copies with sound (%d voices, %d before)' % (nsound(), n0))

fzed(g, 35, 64); loop(); B, a = areas()
check(c.m[UNN] == 4 and [x[1] for x in a] == [0x11, 0x22, 0x44, 0x88], 'UNISON 4: masks 11h 22h 44h 88h (%s)' % [hex(x[1]) for x in a])
cp = [p for _, _, p in a if p != E]

fzed(g, 26, 0); fzed(g, 11, 0); loop()        # another overlay (Voice Pick) in between: the unison overlay comes back from disk
check(r16(0xd400) != 0x4039, 'another overlay loaded in between (%04X)' % r16(0xd400)); c.m[0x8004] = 0xff
ev = bytes(c.m[E:E + 0xc0])
c.log.clear(); fzed(g, 35, 0); loop(); B, a = areas()
check(c.m[UNN] == 1 and a == [] and all(r16(p + 0x10) == 0 and not any(c.m[p:p + 0xc0]) for p in cp), 'OFF: the areas gone, the copies emptied (%s)' % lcd()[-2:])
check(bytes(c.m[E:E + 0xc0]) == ev, 'OFF: the edit voice as it was')
check(nsound() == n0, 'OFF: as many voices with sound as before UNISON')

# DUAL: a second voice with sound, picked
P = None
for n in range(63, 0, -1):
    if r16(V(n) + 0x10) == 0: P = V(n); break
c.m[P:P + 0xc0] = c.m[E:E + 0xc0]; c.m[P + 0x74] ^= 0x40; c.m[P + 0x76] = 0x11; c.m[VPICK] = (P - 0x2288) // 0xc0
pv = bytes(c.m[P:P + 0xc0])
fzed(g, 35, 40); loop(); B, a = areas()
check(c.m[UNN] == 2 and [x[2] for x in a] == [E, P] and r16(UNSV) == P, 'DUAL: layer 2 is the picked voice V%02d' % (c.m[VPICK] + 1))
fzed(g, 36, 30); c.m[E + 0x76] ^= 0x0f; loop()
check(bytes(c.m[P:P + 0xc0]) == pv, 'DUAL: the picked voice is not synced or detuned')
fzed(g, 35, 0); loop(); B, a = areas()
check(a == [] and bytes(c.m[P:P + 0xc0]) == pv and r16(UNSV) == 0, 'DUAL OFF: areas gone, the picked voice kept')
print('ALL PASS' if ok else 'SOME FAIL')
