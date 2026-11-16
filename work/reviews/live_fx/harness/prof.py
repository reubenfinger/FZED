import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ['FZTIMER'] = '1'
import lvh, sig, cyc
bd, band, mix = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
h = lvh.H(bd, signal=sig.signal()); c = h.c; M = h.MAP; L = h.lst
def cen15(b): lo = -(-b * 128 // 15); hi = -(-(b + 1) * 128 // 15) - 1; return (lo + hi) // 2
lp = h.addr('MAIN', 'call L6372')
for n, v in {113: 64, 114: 40, 115: 64, 116: 64, 94: 64, 95: 64}.items(): h.cc(n, v, 30000)
h.cc(112, cen15(band)); h.cc(117, mix); h.cc(119, 127, 30000)
h.run_until(lambda: c.m[M['LVON']] == 2 and c.m[M['LVDIRTY']] == 0 and h.M16(M['CBK']) == 0xffff, 6_000_000); h.run_until(lambda: c.ip == lp)
prof = {}; k = 0; tot = 0
while k < 24:
    ip = c.ip; v0 = h.v30; h.step(); d = h.v30 - v0
    e = prof.setdefault(ip, [0, 0]); e[0] += 1; e[1] += d; tot += d
    if c.ip == lp: k += 1
inv = sorted(M.items(), key=lambda kv: kv[1])
def fn(a):
    best = '?'
    for n, x in inv:
        if x <= a and '.' not in n and 0x6000 <= x < 0xEC00: best = n
        if x > a: break
    return best
byf = {}
for a, (n, cl) in prof.items(): byf[fn(a)] = byf.get(fn(a), 0) + cl
print('clocks per pass', tot // 24)
for f, cl in sorted(byf.items(), key=lambda kv: -kv[1])[:16]: print('%-10s %7d  %4.1f%%' % (f, cl // 24, 100 * cl / tot))
if len(sys.argv) > 4:
    for a in sorted(prof):
        if fn(a) in sys.argv[4].split(','): print('%04X %6d %7d  %s' % (a, prof[a][0] // 24, prof[a][1] // 24, L.get(a, ('?',))[0].strip()[:60]))
