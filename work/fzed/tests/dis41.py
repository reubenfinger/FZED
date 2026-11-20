# FZED41C disintegration (FZED 20 hiss, 21 decay, 22 dropouts), a live stage after the CC112 effect.
#   python3 dis41.py BUILD     (a build folder with fzedflat.bin, fzed.map, fzed.lst and tests/)
# Every call of the stage (DISCH) is checked against a model of it, word for word: the chunk it was given, the age,
# the controls, the chunk's clean offset, the word before it in the voice and the noise state in, the chunk out.
# Also: FZED 20-22 set the controls and DECAY 0 makes the sample new again; the age grows with the timer at
# 4 decay^2 / 65536 of the way each 4096 units; with every control 0 the stage leaves the effect's words alone; live
# off brings back the clean sample; chase and sweep both go through it; capture still refuses live FX.
import os, sys
os.environ['FZTIMER'] = '1'
B = os.path.abspath(sys.argv[1])
sys.path.insert(0, os.path.join(B, '..', 'reviews', 'live_fx', 'harness'))
import lvh, sig

s16 = lambda v: ((v + 0x8000) & 0xffff) - 0x8000

def dunit(u, thr):
    h = ((u + 1) * 40503) & 0xffff
    h = (h & 0xff00) | ((h ^ (h >> 8)) & 0xff)
    h = (h * 40503) & 0xffff
    return h < thr

def model(buf, a, hiss, drop, co, prev, rn):
    ha = (hiss * hiss) >> 3
    if a == 0 and ha == 0: return list(buf), rn
    k = (32767 - 120 * a) & 0xffff
    k = s16(k)
    thr = (drop * a * 2) & 0xffff
    q = co & 2047; u = (co >> 11) & 0xffff
    dr = dunit(u, thr)
    yh = s16(prev) >> 1; out = []
    for w in buf:
        d = s16((s16(w) >> 1) - yh)
        dx = s16(((d * k) << 1) >> 16)
        yh = s16(yh + dx)
        v = s16(yh << 1)
        if dr:
            e = min(q, 2047 - q)
            if e >= 128: v = 0
            else:
                g = s16((128 - e) * 2)
                v = s16(((v * g) >> 8) & 0xffff)
        q += 1
        if q == 2048:
            q = 0; u = (u + 1) & 0xffff; dr = dunit(u, thr)
        if ha:
            rn = (rn * 25173 + 13849) & 0xffff
            n = (s16(rn) * ha * 2) >> 16
            v = v + n
            v = 32767 if v > 32767 else (-32768 if v < -32768 else v)
        out.append(v & 0xffff)
    return out, rn

ok = True
def check(c, msg):
    global ok
    print(('PASS ' if c else 'FAIL ') + msg, flush=True); ok &= bool(c)

N = 6144
h = lvh.H(B, signal=sig.signal(), timing=False); c = h.c; M = h.MAP; g = h.g
EV = g['EV']; c.wr16(EV + 12, h.S + N - 1); h.E = h.S + N; h.fill(sig.signal())
CLEAN = h.voice()
lp = h.addr('MAIN', 'call L6372')
passes = [0]; calls = []; pend = []; chase = [False]; ticks = []
DIS = M['DISCH']
TK = h.addr('DISAGE', 'mov [DTM],dx')
def m32(a): return h.M16(a) | (h.M16(a + 2) << 16)
def step():
    if c.ip == lp:
        passes[0] += 1
        if chase[0]:
            ph = h.S + (passes[0] * 41) % N
            c.m[0x5420] = 1; c.wr16(0x5420 + 0xa, EV); h.u.mem = getattr(h.u, 'mem', {}); h.u.mem[2] = ph & 0xffff; h.u.mem[4] = ph >> 16
    if c.ip == TK: ticks.append(c.r['dx'])
    if c.ip == DIS:
        n = h.M16(M['LVN']); pos = m32(M['LVPOS']); so = m32(M['LVSO']); sd = m32(M['LVSD'])
        buf = [h.M16(M['LVBUF'] + 2 * i) for i in range(n)]
        if pos: prev = c.wave.get((sd + pos - 1) * 2, 0) | (c.wave.get((sd + pos - 1) * 2 + 1, 0) << 8)
        else: prev = buf[0]
        pend.append((c.rd16(c.r['sp']), dict(buf=buf, a=c.m[M['DAGE'] + 3], hiss=c.m[M['DISH']], drop=c.m[M['DISP']],
                     co=(pos + so) & 0xffffffff, prev=prev, rn=h.M16(M['DRN']), n=n)))
    elif pend and c.ip == pend[-1][0]:
        _, d = pend.pop()
        d['out'] = [h.M16(M['LVBUF'] + 2 * i) for i in range(d['n'])]; d['rnout'] = h.M16(M['DRN'])
        calls.append(d)
    h.step()
def until(pred, limit):
    k = 0
    while not pred():
        step(); k += 1
        if k > limit: return False
    return True
def ccp(n, v, np=6):
    until(lambda: c.ip == lp, 10_000_000)
    h.cc(n, v, 0); p = passes[0]
    until(lambda: passes[0] - p >= np, 30_000_000)
def fzed(k, v): ccp(10, 88, 1); ccp(11, k, 1); ccp(10, 89, 1); ccp(11, v, 2)
def run_passes(n):
    p0 = passes[0]; until(lambda: passes[0] - p0 >= n, 60_000_000)
def verify(label):
    bad = 0; first = None; changed = 0
    for i, d in enumerate(calls):
        exp, rn = model(d['buf'], d['a'], d['hiss'], d['drop'], d['co'], d['prev'], d['rn'])
        if exp != d['out'] or rn != d['rnout']:
            bad += 1
            if first is None:
                j = next((j for j in range(len(exp)) if exp[j] != d['out'][j]), -1)
                first = (i, j, d['a'], d['co'], exp[j] if j >= 0 else None, d['out'][j] if j >= 0 else None)
        changed += d['out'] != d['buf']
    check(calls and not bad, '%s: %d stage calls match the model (%d differ%s; %d changed their chunk)' % (label, len(calls), bad, (', first %r' % (first,)) if first else '', changed))
    calls.clear()

def wset(a32): c.wr16(M['DAGE'], a32 & 0xffff); c.wr16(M['DAGE'] + 2, a32 >> 16)

# 1. controls: FZED 20-22 store, DECAY 0 rewinds
fzed(20, 100); fzed(22, 77); fzed(21, 50)
check((c.m[M['DISH']], c.m[M['DISD']], c.m[M['DISP']]) == (100, 50, 77), 'FZED 20 / 21 / 22 set hiss, decay, dropouts (%d %d %d)' % (c.m[M['DISH']], c.m[M['DISD']], c.m[M['DISP']]))
wset(0x12345678); fzed(21, 0)
check(m32(M['DAGE']) == 0 and c.m[M['DISD']] == 0, 'DECAY 0: the age goes back to new (%08X)' % m32(M['DAGE']))
fzed(20, 0); fzed(22, 0)

# 2. TapeHack (CC112 band 0), live on, every control 0: the stage is called and changes nothing; a reference voice
for n, v in {113: 64, 114: 40, 115: 64, 116: 64}.items(): ccp(n, v)
ccp(112, 4, 12); ccp(117, 100, 12); ccp(119, 127, 4)
check(until(lambda: c.m[M['LVON']] == 2 and c.m[M['LVDIRTY']] == 0, 8_000_000), 'live FX on')
run_passes(3 * (N // 128) + 8)
REF = h.voice()
check(calls and all(d['out'] == d['buf'] for d in calls), 'every control 0: %d stage calls, none changed its chunk' % len(calls))
calls.clear()

# 3. a fixed age (decay 0 keeps it), dulling only, then dulling + dropouts, then all three: sweep
for a32, hs, dp, label in ((0x40000000, 0, 0, 'sweep, age 64, dulling'), (0xC0000000, 0, 127, 'sweep, age 192, dropouts 127'),
                           (0xFFFF0000, 90, 60, 'sweep, age 255, hiss 90, dropouts 60')):
    fzed(20, hs); fzed(22, dp); wset(a32)
    run_passes(3 * (N // 128) + 8)
    verify(label)
    if dp == 127:
        z = sum(1 for w in h.voice() if w == 0)
        check(z > 1500, 'age 192, dropouts 127: whole stretches silent (%d words zero)' % z)
check(h.voice() != REF, 'the voice did change')

# 4. chase: the same checks with a note playing the voice
chase[0] = True
wset(0x80000000); fzed(20, 40); fzed(22, 100)
run_passes(3 * (N // 128) + 8)
verify('chase, age 128, hiss 40, dropouts 100')

# 5. ageing with the timer: DECAY 127 for a while, then the rate
fzed(20, 0); fzed(22, 0); wset(0); calls.clear()
fzed(21, 127); a0 = m32(M['DAGE']); ticks.clear()
run_passes(400)
a1 = m32(M['DAGE'])
gaps = [(ticks[i] - ticks[i - 1]) & 0xffff for i in range(1, len(ticks))]
check(a1 - a0 == len(ticks) * 4 * 127 * 127 and len(ticks) > 20 and min(gaps) >= 0x1000 and max(gaps) < 0x1400,
      'DECAY 127: the age grew by 4 x 127^2 at each of %d steps, %s..%s timer units apart' % (len(ticks), min(gaps), max(gaps)))
verify('chase, ageing')
fzed(21, 0)
check(m32(M['DAGE']) == 0, 'DECAY 0 again: new')

# 6. live off: the clean sample comes back exactly (the clean copy is never touched)
wset(0xE0000000); fzed(22, 127); fzed(20, 127); run_passes(3 * (N // 128) + 8); calls.clear()
ccp(119, 0, 4)
until(lambda: c.m[M['LVON']] in (0, 4), 30_000_000)
run_passes(3 * (N // 128) + 8)
check(h.voice() == CLEAN, 'live off: the clean sample is back, word for word')
print('ALL PASS' if ok else 'SOME FAILED')
