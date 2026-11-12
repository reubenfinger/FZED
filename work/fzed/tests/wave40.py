# FZED preset waves: write each wave and every refusal on a build, save what came out, and compare two builds.
#   python3 wave40.py BUILD OUT.json [scribble]   run on BUILD (a folder holding fzedflat.bin) and save the results
#   python3 wave40.py --cmp A.json B.json         compare: the waves and voices must match word for word
#   python3 wave40.py --stack BUILD               the wave overlay refuses when the FZ-call stack reaches its end signature
# scribble: ROM calls 117, 119 and 169 write that many bytes below sp (the FZ's delete has a 412h-byte frame),
# so a stack that reaches the overlay shows up. Default 0x412.
import json, os, sys
T = os.path.dirname(os.path.abspath(__file__))

def boot(build, scribble):
    cwd = os.getcwd(); os.chdir(T); sys.path.insert(0, T)
    g = {'__name__': 'w'}
    src = open('tchop.py').read().replace('perf24.bin', os.path.join(build, 'fzedflat.bin')) \
        .replace("c.codeend=0x8000')", "c.codeend=0xB800')").replace('run(c,u,3_000_000)', 'c.ovl=True; run(c,u,3_000_000)')
    exec(src, g)
    os.chdir(cwd)
    c = g['c']; c.ovl = True
    prev = c.int3
    def i3():
        fn = c.rd16(c.r['sp'])
        if fn in (117, 119, 169) and scribble:
            sp = c.r['sp']
            for a in range(sp - scribble, sp): c.m[a & 0xffff] = 0xEE
        prev()
    c.int3 = i3
    return g, c

def case(build, name, scribble, setup=None, band=1, empty=False):
    g, c = boot(build, scribble); u = g['u']; EV = g['EV']; S, E = g['S'], g['E']
    c.wr16(EV + 0, S); c.wr16(EV + 2, 0); c.wr16(EV + 4, E); c.wr16(EV + 6, 0)    # stored wave start / end
    if empty: c.wr16(EV + 0x10, 0)
    if setup: setup(g, c)
    def cc(n, v): g['midi'](c, 0xb0, n, v); g['run'](c, u, 200000)
    cc(111, band * 8 + 3); cc(9, 0); cc(9, 127); g['run'](c, u, 3_000_000)
    lcd = [x[2] for x in c.log if x[0] == 'lcd'][-2:]
    si = c.rd16(0xe04)
    st = c.rd16(si) | ((c.rd16(si + 2) & 0x1f) << 16)
    words = [c.wave.get(w * 2, 0) | (c.wave.get(w * 2 + 1, 0) << 8) for w in range(st, st + 1808)]
    return {'name': name, 'lcd': lcd, 'voice': list(c.m[si:si + 0xc0]), 'wave': words,
            'flags': [c.m[0x83C2], c.m[0x81EF], c.m[0xD2DA], c.m[0x8344]]}   # BKON CHCNT CAPON LVON

def mem(addr, val):
    def f(g, c): c.m[addr] = val
    return f

def run(build, scribble):
    out = []
    for b in range(1, 8): out.append(case(build, 'wave %d' % b, scribble, band=b))
    out.append(case(build, 'wave 3, empty voice', scribble, band=3, empty=True))
    out.append(case(build, 'band 8 (unused)', scribble, band=8))
    out.append(case(build, 'band 15 (unused)', scribble, band=15))
    def short(g, c): c.wr16(g['EV'] + 4, g['S'] + 1000)
    out.append(case(build, 'voice under 1808 words', scribble, setup=short))
    out.append(case(build, 'bank mode', scribble, setup=mem(0x83C2, 1)))
    out.append(case(build, 'chop slices', scribble, setup=mem(0x81EF, 4)))
    out.append(case(build, 'capture on', scribble, setup=mem(0xD2DA, 1)))
    return out

if __name__ == '__main__':
    if sys.argv[1] == '--cmp':
        a = json.load(open(sys.argv[2])); b = json.load(open(sys.argv[3])); bad = 0
        for x, y in zip(a, b):
            same = x['wave'] == y['wave'] and x['voice'] == y['voice'] and x['lcd'] == y['lcd'] and x['flags'] == y['flags']
            bad += not same
            print(('SAME ' if same else 'DIFF ') + x['name'], x['lcd'][-1:], '' if same else (y['lcd'][-1:],
                  sum(p != q for p, q in zip(x['wave'], y['wave'])), 'wave words differ',
                  [i for i, (p, q) in enumerate(zip(x['voice'], y['voice'])) if p != q][:8]))
        print('cases %d different %d' % (len(a), bad)); sys.exit(1 if bad else 0)
    if sys.argv[1] == '--stack':
        ok = case(sys.argv[2], 'margin', 0x412, band=1, empty=True)['lcd'][-1] == 'WAVE 01 LOADED  '
        print(('PASS ' if ok else 'FAIL ') + 'a 412h-byte FZ-call frame leaves the overlay alone')
        r = case(sys.argv[2], 'deep', 0x430, band=1, empty=True)['lcd'][-1]
        print(('PASS ' if r == 'WAVE: REFUSED   ' else 'FAIL ') + 'a stack that reaches the end signature is refused', r)
        sys.exit(0)
    sc = int(sys.argv[3], 0) if len(sys.argv) > 3 else 0x412
    json.dump(run(sys.argv[1], sc), open(sys.argv[2], 'w'))
    for r in json.load(open(sys.argv[2])): print(r['name'], r['lcd'][-1:])
