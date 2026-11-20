# FZED41C disintegration (FZED 20 hiss, 21 decay, 22 dropouts), a live stage after the CC112 effect.
#   python3 dis41.py BUILD     (a build folder with fzedflat.bin, fzed.map, fzed.lst and tests/)
# Every call of the stage (DISCH) is checked against a model of it, word for word: the chunk it was given, the age,
# the controls, the chunk's clean offset, the word before it in the voice and the noise state in, the chunk out.
# FZED41D: dropouts fade as the age passes them; EVEN AGEING (FZED 23) holds the age until the stage has been round;
# Render with live FX on keeps what they give, in one sweep at one age.
# Also: FZED 20-22 set the controls and DECAY 0 makes the sample new again; the age grows with the timer at
# decay^2 / 64 of the way (high word) each 4096 units; with every control 0 the stage leaves the effect's words alone; live
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
    d = thr - h                         # FZED41D: a stretch fades over DTH - h = 0..4096
    return 256 if d <= 0 else max(0, 256 - (d >> 4))

def model(buf, a, hiss, drop, co, prev, rn):
    ha = hiss                            # FZED41E: hiss on when HISS > 0
    if a == 0 and ha == 0: return list(buf), rn
    k = (((256 - a) ** 2) >> 1) | 0x300
    thr = (drop * a * 2) & 0xffff
    q = co & 2047; u = (co >> 11) & 0xffff
    dr = dunit(u, thr)
    yh = s16(prev) >> 1; out = []
    for i, w in enumerate(buf):
        if a:
            d = s16((s16(w) >> 1) - yh)
            dx = s16(((d * k) << 1) >> 16)
            yh = s16(yh + dx)
            v = s16(yh << 1)
        else: v = s16(w)
        if dr != 256:
            e = min(q, 2047 - q)
            g = max((128 - e) * 2 if e < 128 else 0, dr)
            v = s16(((v * g) >> 8) & 0xffff)
        q += 1
        if q == 2048:
            q = 0; u = (u + 1) & 0xffff; dr = dunit(u, thr)
        if ha and not i & 1:               # FZED41E: every other word
            rn ^= (rn << 7) & 0xffff; rn ^= rn >> 9; rn ^= (rn << 8) & 0xffff     # xorshift 7, 9, 8
            n = s16(rn) >> (2 + ((128 - hiss) >> 4))
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
passes = [0]; calls = []; pend = []; chase = [False]; ticks = []; tcnt = []
DIS = M['DISCH']
TK = h.addr('DTICK', 'mov [DTM],dx')
def m32(a): return h.M16(a) | (h.M16(a + 2) << 16)
def step():
    if c.ip == lp:
        passes[0] += 1
        if chase[0]:
            ph = h.S + (passes[0] * 41) % N
            c.m[0x5420] = 1; c.wr16(0x5420 + 0xa, EV); h.u.mem = getattr(h.u, 'mem', {}); h.u.mem[2] = ph & 0xffff; h.u.mem[4] = ph >> 16
    if c.ip == TK: ticks.append(c.r['dx']); tcnt.append(m32(M['DCNT']))
    if c.ip == DIS:
        n = h.M16(M['LVN']); pos = m32(M['LVPOS']); so = m32(M['LVSO']); sd = m32(M['LVSD'])
        buf = [h.M16(M['LVBUF'] + 2 * i) for i in range(n)]
        if pos: prev = c.wave.get((sd + pos - 1) * 2, 0) | (c.wave.get((sd + pos - 1) * 2 + 1, 0) << 8)
        else: prev = buf[0]
        pend.append((c.rd16(c.r['sp']), dict(buf=buf, a=c.m[M['DAGE'] + 3], hiss=c.m[M['DISH']], drop=c.m[M['DISP']],
                     co=(pos + so) & 0xffffffff, prev=prev, rn=h.M16(M['DRN']), n=n, pos=pos, seg=c.m[M['LVSEGI']])))
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
check(a1 - a0 == len(ticks) * 1024 * 127 * 127 and len(ticks) > 20 and min(gaps) >= 0x1000 and max(gaps) < 0x1400,
      'DECAY 127: the age grew by 1024 x 127^2 at each of %d steps, %s..%s timer units apart (new to gone in %.1f s)' % (len(ticks), min(gaps), max(gaps), 65536 * 65536 / (1024 * 127 * 127) * 4096 / 104000))
verify('chase, ageing')
fzed(21, 0)
check(m32(M['DAGE']) == 0, 'DECAY 0 again: new')

# 6. live off: the clean sample comes back exactly (the clean copy is never touched)
wset(0xE0000000); fzed(22, 127); fzed(20, 127); run_passes(3 * (N // 128) + 8); calls.clear()
ccp(119, 0, 4)
until(lambda: c.m[M['LVON']] in (0, 4), 30_000_000)
run_passes(3 * (N // 128) + 8)
check(h.voice() == CLEAN, 'live off: the clean sample is back, word for word')

# 7. EVEN AGEING (FZED 23): the age moves on only after the stage has had as many words as the clean copy holds
chase[0] = True
ccp(119, 127, 4)
check(until(lambda: c.m[M['LVON']] == 2 and c.m[M['LVDIRTY']] == 0, 8_000_000), 'live FX on again')
fzed(23, 127); fzed(22, 100); fzed(21, 127); ticks.clear(); tcnt.clear(); calls.clear()
run_passes(500)
L = m32(M['LVLEN'])
check(c.m[M['DIS4']] == 127 and ticks and all(n >= L for n in tcnt),
      'EVEN AGEING: %d ageing steps, each after at least %d words through the stage (%s)' % (len(ticks), L, tcnt[:6]))
n_even = len(ticks)
verify('chase, even ageing, dropouts 100')
fzed(23, 0); ticks.clear(); run_passes(500)
check(len(ticks) > n_even, 'EVEN AGEING off: the timer alone again (%d steps in the same time, %d with it on)' % (len(ticks), n_even))

# 8. Render with live FX on: one sweep over every word at one age, then kept (live FX released, clean copy dropped)
fzed(21, 0); wset(0xA0000000); fzed(22, 90); fzed(20, 30); chase[0] = False
run_passes(40); calls.clear(); a_before = m32(M['DAGE'])
ccp(118, 0, 2); ccp(118, 127, 2)
until(lambda: c.m[M['LVON']] == 0, 80_000_000); run_passes(4)
sweep = [d for d in calls]
verify('Render with live FX on (the freeze sweep)')
v = h.voice(); L = m32(M['LVLEN'])
last = {}
for d in sweep: last[d['pos']] = d['out']
okv = all(v[p:p + len(o)] == o for p, o in last.items())
check(okv and set(last) >= set(range(0, L, 128)) and all(d['a'] == 0xA0 for d in sweep) and m32(M['DAGE']) == a_before,
      'freeze: every 128-word piece of the %d-word voice went through the stage at age A0 (%d calls), and the voice keeps exactly what they gave' % (L, len(sweep)))
L2 = [x[2].rstrip() for x in c.log if x[0] == 'lcd']
check(c.m[M['LVON']] == 0 and 'RENDERED (LIVE)' in L2[-3:] and v != CLEAN, 'freeze: live FX released, RENDERED (LIVE) shown, the processed sample stays (%r)' % L2[-2:])
print('ALL PASS' if ok else 'SOME FAILED')
