# RH4 EXT module 5 ADDITIVE: FZED 19 = 40 picks it, Render runs it; WAVETABLE (module 4) makes the table, then ADDITIVE
# writes every frame from its harmonics. Checks the frames' harmonic content (a DFT of each frame) against the controls.
#   python3 ad5.py BUILD   (a folder holding fzedflat.bin and fzed.map)
import os, sys, math
os.environ['FZTIMER'] = '1'
T = os.path.dirname(os.path.abspath(__file__))
sys.argv = [sys.argv[0], sys.argv[1]]
exec(open(os.path.join(T, 'ext41.py')).read().split('ok = True')[0])
ok = True
def check(c_, msg):
    global ok
    print(('PASS ' if c_ else 'FAIL ') + msg); ok = ok and c_
L = 327
def run(shape, bright=64, oe=64, form=0, width=32, comb=0, frames=0, sweep=64, panel=None):
    g = boot(); c = g['c']
    o8 = c.rd8                                       # as glide41.py: DS = 1000h reads the sample window (LVRD)
    def rd8(x):
        if c.ds == 0x1000 and c.pfx is None: return c.wave.get(c.wa(x), 0)
        return o8(x)
    c.rd8 = rd8
    c.rd16 = lambda x: rd8(x) | (rd8(x + 1) << 8)
    EV = c.rd16(0xe04); c.wr16(EV + 0x10, 0)          # an empty edit voice
    if panel:
        for i in range(48): c.m[0x4DC + i] = panel.get(i + 1, 0)
    fzed(g, 19, 40)
    for n, v in zip((113, 114, 115, 116), (shape, bright, oe, form)): cc(g, n, v)
    for k, v in zip((30, 31, 32, 33), (width, comb, frames, sweep)): fzed(g, k, v)
    s0 = c.steps; render(g); g['run'](c, g['u'], 60_000_000)
    lcd = [x[2] for x in c.log if x[0] == 'lcd'][-3:]
    d32 = lambda a: c.rd16(a) | (c.rd16(a + 2) << 16)
    st = d32(EV + 0x14) & 0x1fffff
    nf = 8 << (frames >> 5)
    def frame(k):
        w = [c.wave.get(2 * (st + k * L + i), 0) | (c.wave.get(2 * (st + k * L + i) + 1, 0) << 8) for i in range(L)]
        return [x - 65536 if x > 32767 else x for x in w]
    return g, c, lcd, frame, nf, c.steps - s0, EV
def spec(w, n=12):
    out = []
    for h in range(1, n + 1):
        re_ = sum(x * math.cos(2 * math.pi * h * i / L) for i, x in enumerate(w))
        im = sum(x * math.sin(2 * math.pi * h * i / L) for i, x in enumerate(w))
        out.append(math.hypot(re_, im) * 2 / L)
    return out
g, c, lcd, frame, nf, steps, EV = run(shape=40)            # SAW
f0 = frame(0); sp = spec(f0)
check(any('ADDITIVE OK' in x for x in lcd), 'SAW: ADDITIVE OK on the LCD %s (%d emulated steps)' % (lcd, steps))
check(28000 <= max(abs(x) for x in f0) <= 30000, 'every frame scaled to a 30000 peak: %d' % max(abs(x) for x in f0))
r = [sp[h - 1] / sp[0] for h in (2, 3, 4, 8)]
check(all(abs(x * h - 1) < 0.2 for x, h in zip(r, (2, 3, 4, 8))), 'SAW: harmonic h at about 1/h of the fundamental: %s' % ['%.3f' % x for x in r])
check(c.m[EV + 0xb0] == 45 and frame(7) == f0, 'original key A2 (45); no sweep: frame 8 = frame 1')
_, c, lcd, frame, nf, steps, EV = run(shape=70)            # SQUARE
sp = spec(frame(0))
check(sp[1] / sp[0] < 0.01 and sp[3] / sp[0] < 0.01 and abs(sp[2] / sp[0] * 3 - 1) < 0.2, 'SQUARE: odd only, 1/h: %s' % ['%.3f' % (x / sp[0]) for x in sp[:6]])
_, c, lcd, frame, nf, steps, EV = run(shape=40, bright=32)  # SAW, darker by 1/h
sp = spec(frame(0))
check(abs(sp[1] / sp[0] * 4 - 1) < 0.25 and abs(sp[3] / sp[0] * 16 - 1) < 0.3, 'brightness 32: SAW x 1/h = 1/h^2 (triangle-like): %s' % ['%.3f' % (x / sp[0]) for x in sp[:5]])
_, c, lcd, frame, nf, steps, EV = run(shape=40, oe=0)       # SAW, no even
sp = spec(frame(0))
check(sp[1] / sp[0] < 0.01 and sp[3] / sp[0] < 0.01, 'odd/even 0: the even harmonics gone: %s' % ['%.3f' % (x / sp[0]) for x in sp[:5]])
_, c, lcd, frame, nf, steps, EV = run(shape=40, comb=8)     # band 1: N 2, k 0: h = 1, 3, 5
sp = spec(frame(0))
check(sp[1] / sp[0] < 0.01 and sp[2] / sp[0] > 0.2, 'COMB band 1 (2,0): harmonics 1, 3, 5 kept, the rest gone')
_, c, lcd, frame, nf, steps, EV = run(shape=100, panel={1: 99, 3: 50, 5: 25})   # PANEL
sp = spec(frame(0))
r3, r5 = sp[2] / sp[0], sp[4] / sp[0]
check(abs(r3 - 0.5) < 0.08 and abs(r5 - 0.25) < 0.06 and sp[1] / sp[0] < 0.01, 'PANEL: the FZ\'s levels 99 / 50 / 25 at 1, 3, 5: %.3f %.3f' % (r3, r5))
_, c, lcd, frame, nf, steps, EV = run(shape=40, form=64)    # SAW, formant at 2^(64 x 13 / 256) ~ harmonic 9.5
sp = spec(frame(0), 16)
check(sp[8] / sp[0] > 2 / 9, 'FORMANT 64: around harmonic 9 boosted over the saw\'s 1/9: %s' % ['%.2f' % (x / sp[0]) for x in sp[6:12]])
_, c, lcd, frame, nf, steps, EV = run(shape=40, form=30, sweep=80, frames=32)   # 16 frames
a = spec(frame(0), 16); b = spec(frame(15), 16)
pa = max(range(16), key=lambda i: a[i] * (i + 1)); pb = max(range(16), key=lambda i: b[i] * (i + 1))
check(nf == 16 and pa + 1 in (2, 3, 4) and pb + 1 in range(6, 13), 'SWEEP 80, 16 frames: the formant moves from about harmonic 3 to about 9 (%d -> %d)' % (pa + 1, pb + 1))
print('ALL PASS' if ok else 'SOME FAIL')
