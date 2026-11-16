# live linear crush with DeFreq vs render of the same settings, same build; rate = voice rate index (0-3)
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ['FZTIMER'] = '1'
import lvh, sig
bd = sys.argv[1]; rate = int(sys.argv[2]); df = int(sys.argv[3]); mix = int(sys.argv[4]); bits = int(sys.argv[5])
SIG = sig.signal(); N = 1536
h = lvh.H(bd, signal=SIG, timing=False); c = h.c; M = h.MAP
EV = h.g['EV']; c.wr16(EV + 12, h.S + N - 1); h.E = h.S + N
lp = h.addr('MAIN', 'call L6372'); passes = [0]
def step():
    if c.ip == lp: passes[0] += 1
    h.step()
def until(pred, limit):
    k = 0
    while not pred():
        step(); k += 1
        if k > limit: return False
    return True
def ccp(n, v, np=6):
    until(lambda: c.ip == lp, 10_000_000); h.cc(n, v, 0); p = passes[0]
    until(lambda: passes[0] - p >= np, 30_000_000)
voice = None
for n, v in {113: bits, 114: df, 115: 64, 116: 64, 94: 64, 95: 64}.items(): ccp(n, v)
ccp(112, 47, 12); ccp(117, mix, 12)
ccp(119, 127, 4)
until(lambda: c.m[M['LVON']] == 2 and c.m[M['LVDIRTY']] == 0, 6_000_000)
vo = h.M16(M['LVVOI']); c.m[vo + 0xb1] = (c.m[vo + 0xb1] & ~3) | rate
p0 = passes[0]; until(lambda: passes[0] - p0 >= 3 * (N // 128) + 8, 30_000_000)
live = h.voice(); fq = h.M16(M['FXFREQ'])
ccp(119, 0, 4); until(lambda: c.m[M['LVON']] in (0, 4), 8_000_000)
clean = h.voice()
ccp(118, 0, 2); ccp(118, 127, 3)
ren = h.voice()
d = [i for i in range(N) if live[i] != ren[i]]
print('rate %d DeFreq %d mix %d bits %d: hold %d words | live == render: %s (%d differ, first %s) | changed from dry: %d words | restored clean: %s'
      % (rate, df, mix, bits, fq, not d, len(d), d[:4], sum(1 for a, b in zip(ren, SIG[:N]) if a != b), clean == SIG[:N]))
