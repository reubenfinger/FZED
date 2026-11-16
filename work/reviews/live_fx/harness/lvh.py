# Live FX harness: boots a build in the repo's emulator, turns live FX on for one mode / setting and
# returns the processed voice plus cycle totals.  usage: import lvh; h = lvh.H(builddir)
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cyc
class H:
    def __init__(s, bdir, signal=None, timing=True):
        s.bdir = bdir; cwd = os.getcwd(); os.chdir(os.path.join(bdir, 'tests'))
        g = {'__name__': 'lv'}
        src = open('tchop.py').read().replace('perf24.bin', os.path.join(bdir, 'fzedflat.bin')).replace("c.codeend=0x8000')", "c.codeend=0xB800')").replace('run(c,u,3_000_000)', 'c.ovl=True; run(c,u,3_000_000)')
        sys.path.insert(0, os.getcwd())
        exec(src, g)
        sys.path.pop(0); os.chdir(cwd)
        s.g = g; s.c = c = g['c']; s.u = g['u']; c.ovl = True
        o8, o16 = c.rd8, c.rd16      # test-model extension: DS = 1000h reads the sample window, as ES = 1000h already does
        def rd8(a):
            if c.ds == 0x1000 and c.pfx is None: return c.wave.get(c.wa(a), 0)
            return o8(a)
        def rd16(a):
            if c.ds == 0x1000 and c.pfx is None: return rd8(a) | (rd8(a + 1) << 8)
            return o16(a)
        c.rd8, c.rd16 = rd8, rd16
        s.MAP = {}
        for l in open(os.path.join(bdir, 'fzed.map')):
            p = l.split()
            if len(p) in (2, 3) and re.fullmatch(r'[0-9A-F]{4,8}', p[0]):
                try: s.MAP[p[-1]] = int(p[1] if len(p) == 3 else p[0], 16)
                except ValueError: pass
        s.S, s.E = g['S'], g['E']
        s.timing = timing
        s.lst, s.lines = cyc.load_listing(os.path.join(bdir, 'fzed.lst'))
        s.v30 = s.i86 = s.wait = s.ins = 0; s.unknown = {}; s.spans = {}; s.open = {}; s.acc = {}; s.rom = {}
        if signal: s.fill(signal)
    def M16(s, a): return s.c.m[a] | (s.c.m[a + 1] << 8)
    def fill(s, sig):
        c = s.c
        for i, w in enumerate(range(s.S, s.E)):
            v = sig[i % len(sig)] & 0xffff; c.wave[w * 2] = v & 0xff; c.wave[w * 2 + 1] = v >> 8
    def voice(s):
        c = s.c
        return [c.wave.get(w * 2, 0) | (c.wave.get(w * 2 + 1, 0) << 8) for w in range(s.S, s.E)]
    def addr(s, label, text=None, nth=1):
        """address of the nth line containing text after label (a 'NAME:' source label)"""
        on = False; k = 0
        for a, t in s.lines:
            if not on:
                if re.match(r'\s*\d+\s+(?:[0-9A-F]{8}\s+\S+\s+)?(?:<\d+>\s)?' + re.escape(label) + ':', t) or t.lstrip().startswith(label + ':') or re.search(r'(^|\s)' + re.escape(label) + r':', t):
                    on = True
                    if text is None and a is not None: return a
                    if text is None: continue
                else: continue
            if a is None: continue
            if text is None: return a
            if text in t:
                k += 1
                if k == nth: return a
        raise KeyError((label, text))
    def span(s, name, start, end):
        s.spans.setdefault(start, []).append((name, end)); s.acc.setdefault(name, [0, 0, 0, 0, 0])
    def step(s):
        c = s.c
        if not s.timing:
            s.u.tick(); c.step(); return
        ip = c.ip
        for name in [n for n, o in s.open.items() if o[0] == ip and o[4] != s.ins]:
            e, a, b, w, i = s.open.pop(name); t = s.acc[name]
            t[0] += 1; t[1] += s.v30 - a; t[2] += s.i86 - b; t[3] += s.wait - w; t[4] += s.ins - i
        for name, end in s.spans.get(ip, ()):
            if name not in s.open: s.open[name] = (end, s.v30, s.i86, s.wait, s.ins)
        e = s.lst.get(ip)
        cx = c.r['cx']; es = c.es
        s.u.tick(); c.step(); s.ins += 1
        if e is None:
            s.unknown[ip] = s.unknown.get(ip, 0) + 1; return
        txt, ln = e
        try:
            if 'int3' in txt.split(';')[0]:
                fn = c.api[-1][0] if c.api else -1; s.rom[fn] = s.rom.get(fn, 0) + 1
            v, i, acc = cyc.cost(txt, taken=(c.ip != ((ip + ln) & 0xffff)), n=cx, cl=cx)
        except cyc.Unknown:
            s.unknown[txt.strip()] = s.unknown.get(txt.strip(), 0) + 1; return
        s.v30 += v; s.i86 += i
        if acc and (es == 0x1000 or 'movs' in txt): s.wait += acc
    def run(s, n):
        for _ in range(n):
            if s.c.exited: return
            s.step()
    def run_until(s, pred, limit=20_000_000):
        k = 0
        while not pred():
            s.step(); k += 1
            if k >= limit: raise RuntimeError('limit')
        return k
    def cc(s, n, v, steps=150000):
        p = s.c.pfx; s.c.pfx = None; s.g['midi'](s.c, 0xb0, n, v); s.c.pfx = p; s.run(steps)
    def lcd(s, n=2): return [x[2] for x in s.c.log if x[0] == 'lcd'][-n:]
    def reset_counts(s):
        s.v30 = s.i86 = s.wait = s.ins = 0; s.open = {}; s.rom = {}
        for k in s.acc: s.acc[k] = [0, 0, 0, 0, 0]
