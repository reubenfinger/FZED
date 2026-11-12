# equivalence run: every live mode over the same test voice; writes the processed voices as JSON
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ['FZTIMER'] = '1'
import lvh, sig, json
bd, out = sys.argv[1], sys.argv[2]
bands = [int(x) for x in sys.argv[3].split(',')]
kind = sys.argv[4] if len(sys.argv) > 4 else 'sweep'; chase = kind == 'chase'
cov = set(); SIG = sig.signal()
N = 1536
h = lvh.H(bd, signal=sig.signal(), timing=False); c = h.c; M = h.MAP; g = h.g
EV = g['EV']; c.wr16(EV + 12, h.S + N - 1); h.E = h.S + N
def cen15(b): lo = -(-b * 128 // 15); hi = -(-(b + 1) * 128 // 15) - 1; return (lo + hi) // 2
lp = h.addr('MAIN', 'call L6372')
PS = [({113: 64, 114: 40, 115: 64, 116: 64, 94: 64, 95: 64}, [127, 126, 100, 64, 1, 0]),
      ({113: 20, 114: 100, 115: 110, 116: 20, 94: 100, 95: 10}, [127, 90]),
      ({113: 127, 114: 0, 115: 5, 116: 127, 94: 5, 95: 127}, [127, 33])]
res = {}
passes = [0]
def step():
    if c.ip == lp:
        passes[0] += 1
        if chase:                                   # a note plays the voice; its address moves with the pass count
            ph = h.S + (passes[0] * 37) % N
            c.m[0x5420] = 1; c.wr16(0x5420 + 0xa, EV); h.u.mem = getattr(h.u, 'mem', {}); h.u.mem[2] = ph & 0xffff; h.u.mem[4] = ph >> 16
    cov.add(c.ip); h.step()
def until(pred, limit):
    k = 0
    while not pred():
        step(); k += 1
        if k > limit: return False
    return True
def ccp(n, v, np=6):                          # send at a main-loop boundary, then wait a number of passes (not steps)
    until(lambda: c.ip == lp, 10_000_000)
    h.cc(n, v, 0); p = passes[0]
    until(lambda: passes[0] - p >= np, 30_000_000)
for b in bands:
    for ps, mixes in PS:
        for mix in mixes:
            for n, v in ps.items(): ccp(n, v)
            ccp(112, cen15(b), 12); ccp(117, mix, 12)
            key = '%d|%s|%d' % (b, ','.join('%d=%d' % kv for kv in sorted(ps.items())), mix)
            if kind == 'render':
                h.fill(SIG); ccp(118, 0, 2); n0 = len(c.log); ccp(118, 127, 3)
                res[key] = {'fxm': c.m[M['FXM']], 'voice': h.voice(), 'restored': [], 'lcd': [x[2] for x in c.log[n0:] if x[0] == 'lcd'][:4]}
                print(key, 'render', res[key]['lcd'][:2], sum(res[key]['voice']) & 0xffffff, flush=True); continue
            ccp(119, 127, 4)
            if not until(lambda: c.m[M['LVON']] == 2 and c.m[M['LVDIRTY']] == 0 and h.M16(M['CBK']) == 0xffff, 6_000_000):
                res[key] = ['not live', h.lcd(1)]; h.cc(119, 0, 200000); print(key, 'not live', flush=True); continue
            p0 = passes[0]
            until(lambda: passes[0] - p0 >= 3 * (N // 128) + 8, 30_000_000)     # the sweep goes round at least twice
            v = h.voice()
            res[key] = {'fxm': c.m[M['FXM']], 'voice': v, 'lvpos': h.M16(M['LVPOS'])}
            print(key, 'fxm', c.m[M['FXM']], 'sum', sum(v) & 0xffffff, flush=True)
            ccp(119, 0, 4)
            until(lambda: c.m[M['LVON']] in (0, 4), 8_000_000)
            res[key]['restored'] = h.voice()
res['_cov'] = {n: (M[n] in cov) for n in ('MIXOV', 'MIXOV.p', 'FXLBW', 'FXLQW', 'SQRTQ', 'MIXW', 'MIXW.o', 'FXLTM.of', 'FXLCM.of', 'FXLRM.of', 'FXLU.of', 'SVK8.o', 'FXSMP', 'FXLG', 'LVKSCH.of', 'FXLXW', 'FXLDW', 'FXLEW') if n in M}
res['_cov']['chase chunk ran'] = h.addr('LVRUN', 'call LVCHK', 1) in cov
json.dump(res, open(out, 'w'))
