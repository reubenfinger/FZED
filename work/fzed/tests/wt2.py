# RH6 EXT module 4, WAVETABLE 2: WAVETABLE's table with four other types. BYTEBEAT and CHAOS are checked word for word
# against models; FEEDBACK FM's first frame is a plain sine (WAVETABLE SYNC's first frame) and it grows harmonics along
# the sweep; CZ RESONANCE's frames fade across each cycle and ring faster along the sweep. Also: the module numbers
# (1 EQ, 2 BACKUP, 3 WAVETABLE, 4 WAVETABLE 2, 5 ADDITIVE) and the sector each loads from.
#   python3 wt2.py BUILD   (a folder holding fzedflat.bin and fzed.map)
import os, sys, math
os.environ['FZTIMER'] = '1'
T = os.path.dirname(os.path.abspath(__file__))
sys.argv = [sys.argv[0], sys.argv[1]]
exec(open(os.path.join(T, 'ext41.py')).read().split('ok = True')[0])
ok = True
def check(c_, msg):
    global ok
    print(('PASS ' if c_ else 'FAIL ') + msg); ok = ok and c_
L, F, B = 82, 8, 127
def make(module, typ):
    g = boot(); c = g['c']
    EV = c.rd16(0xe04); c.wr16(EV + 0x10, 0)
    fzed(g, 19, module * 8)
    for n, v in zip((113, 114, 115, 116), (typ * 32 + 8, 0, 0, B)): cc(g, n, v)
    c.log.clear(); render(g); g['run'](c, g['u'], 4_000_000)
    lcd = [x[2].strip() for x in c.log if x[0] == 'lcd']
    d32 = lambda a: c.rd16(a) | (c.rd16(a + 2) << 16)
    st = d32(EV + 0x14) & 0x1fffff
    def frame(k, n=L):
        w = [c.wave.get(2 * (st + k * L + i), 0) | (c.wave.get(2 * (st + k * L + i) + 1, 0) << 8) for i in range(n)]
        return [x - 65536 if x > 32767 else x for x in w]
    return c, lcd, frame, EV, c.rd16(0xD400)
WTIN = (1 << 32) // L
phase = lambda i: ((i * WTIN) >> 16) & 0xffff
m_of = lambda k: k * 2 * B // (F - 1)
out = lambda s: (s * 52428) >> 16                # x 0.8 of full scale, as WAVETABLE writes it
def bytebeat(k):
    m = m_of(k); a = 1 + (m >> 4); b = 3 + (m >> 3); r = []
    for i in range(L):
        t = phase(i) >> 8; v = ((t * a) ^ ((t * b) >> 2)) & 255
        r.append(out((v - 128) << 8))
    return r
def chaos(k):
    m = m_of(k); r8 = 896 + (m >> 1); x = 0x8000; r = []
    for i in range(L):
        p = (x * ((65536 - x) & 0xffff)) >> 16; x = ((p * r8) >> 8) & 0xffff
        r.append(out(x - 0x8000))
    return r
c, lcd, fr, EV, sig = make(4, 2)
check('EXT WAVETABLE 2' in lcd and 'TABLE 2 READY' in lcd and sig == 0x4037, 'FZED 19 = 32: module 4 WAVETABLE 2 from sector 55 (%04X): %s' % (sig, lcd[-3:]))
check(all(fr(k) == bytebeat(k) for k in range(F)), 'BYTEBEAT: every frame matches the model')
check(c.m[EV + 0xb0] == 69 and fr(0) != fr(7), 'original key A4 for 82 words (%d); the frames differ along the sweep' % c.m[EV + 0xb0])
c, lcd, fr, EV, sig = make(4, 3)
bad = [k for k in range(F) if fr(k) != chaos(k)]
check(not bad, 'CHAOS: every frame matches the model (logistic map, r 3.5 to 4)%s' % (' differ: %s' % bad if bad else ''))
c, lcd, fr, EV, sig = make(4, 0); fm = [fr(k) for k in range(F)]
c, lcd, fr, EV, sig = make(3, 0); sync0 = fr(0)
check(sig == 0x4036 and fm[0] == sync0, 'FEEDBACK FM frame 1 = WAVETABLE (module 3, sector 54) SYNC frame 1, a plain sine')
def h(w, n):
    re_ = sum(x * math.cos(2 * math.pi * n * i / L) for i, x in enumerate(w)); im = sum(x * math.sin(2 * math.pi * n * i / L) for i, x in enumerate(w))
    return math.hypot(re_, im)
check(h(fm[0], 2) < 0.02 * h(fm[0], 1) and h(fm[7], 2) > 0.2 * h(fm[7], 1), 'FEEDBACK FM: harmonics grow along the sweep (H2/H1 %.3f -> %.3f)' % (h(fm[0], 2) / h(fm[0], 1), h(fm[7], 2) / h(fm[7], 1)))
c, lcd, fr, EV, sig = make(4, 1); z = [fr(k) for k in range(F)]
cross = lambda w: sum(1 for a, b in zip(w, w[1:]) if (a < 0) != (b < 0))
env = lambda w: (max(abs(x) for x in w[:L // 4]), max(abs(x) for x in w[-L // 4:]))
e0, e7 = env(z[7])
check(cross(z[7]) > 3 * max(cross(z[0]), 1) and e0 > 3 * e7, 'CZ RESONANCE: rings faster along the sweep (%d -> %d crossings) and fades across the cycle (%d -> %d)' % (cross(z[0]), cross(z[7]), e0, e7))
c, lcd, fr, EV, sig = make(5, 0)
check(sig in (0x4038, 0x4036) and 'EXT ADDITIVE' in lcd, 'module 5 is still ADDITIVE: %s' % lcd[:6])
print('ALL PASS' if ok else 'SOME FAIL')
