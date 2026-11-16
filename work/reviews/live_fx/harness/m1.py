import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ['FZTIMER'] = '1'
import lvh, sig, json
bd = sys.argv[1]; out = sys.argv[2]; mixes = [int(x) for x in sys.argv[3].split(',')]
bands = [int(x) for x in sys.argv[4].split(',')] if len(sys.argv) > 4 else list(range(15))
h = lvh.H(bd, signal=sig.signal()); c = h.c; M = h.MAP
def cen15(b): lo = -(-b * 128 // 15); hi = -(-(b + 1) * 128 // 15) - 1; return (lo + hi) // 2
L = h.lst
def nxt(a): return a + L[a][1]
lp = h.addr('MAIN', 'call L6372'); h.span('pass', lp, lp)
for nm, lab, txt, nth in (('lvrunx', 'MAIN', 'call LVRUNX', 1), ('matrix', 'MAIN', 'call MATRIX', 1), ('captick', 'MAIN', 'call CAPTICK', 1),
                          ('rvpatch', 'MAIN', 'call RVPATCH', 1), ('parse', 'MAIN', 'call PARSE', 1), ('l6372', 'MAIN', 'call L6372', 1),
                          ('findph', 'LVRUN', 'call LVFINDPH', 1), ('lvchk_chase', 'LVRUN', 'call LVCHK', 1), ('lvchk_sweep', 'LVRUN', 'call LVCHK', 2),
                          ('rd', 'LVCHK', 'call LVRD', 1), ('inner', 'LVCHK', 'call [LVLP]', 1), ('wr', 'LVCHK', 'call LVWR', 1), ('lvseg', 'LVCHK', 'call LVSEG', 1)):
    a = h.addr(lab, txt, nth); h.span(nm, a, nxt(a))
res = {}
base = {113: 64, 114: 40, 115: 64, 116: 64, 94: 64, 95: 64}
for b in bands:
    for mix in mixes:
        for n, v in base.items(): h.cc(n, v, 30000)
        h.cc(112, cen15(b), 60000); h.cc(117, mix, 60000)
        h.cc(119, 127, 30000)
        try:
            h.run_until(lambda: c.m[M['LVON']] == 2 and c.m[M['LVDIRTY']] == 0 and h.M16(M['CBK']) == 0xffff, 6_000_000)
        except RuntimeError:
            print(b, mix, 'not live:', h.lcd(2), 'LVON', c.m[M['LVON']]); res['%d/%d' % (b, mix)] = None; h.cc(119, 0, 400000); continue
        fxm = c.m[M['FXM']]; lvlp = h.M16(M['LVLP'])
        h.run_until(lambda: c.ip == lp); h.reset_counts(); k = 0
        while h.acc['inner'][0] < 40 and k < 400:          # 40 processed chunks (sweep only: no note is playing)
            h.step()
            if c.ip == lp: k += 1
        h.run_until(lambda: c.ip == lp)
        acc = {n: list(v) for n, v in h.acc.items()}
        name = [n for n, a in M.items() if a == lvlp and n.startswith(('FXL', 'SVL'))]
        h.run(1_500_000)                                   # let the sweep cover the voice a few times
        voice = h.voice()
        res['%d/%d' % (b, mix)] = {'fxm': fxm, 'loop': name[0] if name else hex(lvlp), 'acc': acc, 'rom': dict(h.rom), 'voice': voice, 'unknown': {str(k2): v for k2, v in h.unknown.items()}}
        p = acc['pass']; i = acc['inner']
        print(b, mix, 'FXM', fxm, name, 'pass n=%d v30=%.0f i86=%.0f' % (p[0], p[1] / max(1, p[0]), p[2] / max(1, p[0])), 'inner n=%d v30/word=%.1f i86/word=%.1f' % (i[0], i[1] / max(1, i[0]) / 128, i[2] / max(1, i[0]) / 128), flush=True)
        h.cc(119, 0, 30000)
        h.run_until(lambda: c.m[M['LVON']] in (0, 4), 6_000_000)
json.dump(res, open(out, 'w'))
