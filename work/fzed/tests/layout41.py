# FZED41R chop LAYOUT (FZED 26): ONE KEY, SPREAD, SPREAD LOOP, LAST WIDE (looped).   VER=fzed python3 layout41.py
import os
V = os.environ.get('VER', 'fzed')
exec(open('romfix.py').read())
src = romfix(open('cap_t.py').read()).replace('perf38t', V)
exec(src.split("cc(102, 64); cc(103, 5 * 8)")[0])
def m(*b): midi(c, *b); run(c, u, 250000)
def par(n, v, ch=0): m(0xb0 | ch, 10, n); m(0xb0 | ch, 11, v)
EVp = lambda: c.rd16(0xe04)
ok = True
lpok = lambda x: x[0] == 0x0800 and x[1] == x[2] and x[3] == x[4] - 8 and x[5] == 0 and x[6] == 1022   # RH2: loop end 8 words before the play end, held
def res(name, k, info=''):
    global ok
    print(('PASS ' if k else 'FAIL ') + name, info); ok = ok and k
d32 = lambda a: c.rd16(a) | (c.rd16(a + 2) << 16)
try:
    ev0 = EVp(); c.wr16(ev0, 0x1000); c.wr16(ev0 + 4, 0x2008); c.wr16(ev0 + 0x12, 0x0808)   # a one-shot source
    nxt = [0x30000]; p117 = c.int3
    def i3a():
        sp = c.r['sp']; fn = c.rd16(sp); a = [c.rd16(sp + 2 * i) for i in range(1, 5)]
        if fn == 117 and a[2] == 1816 and a[3] == 0:
            si = a[0]; s0 = nxt[0]; e0 = s0 + 1816; nxt[0] = e0 + 16
            for off, v in ((0, s0), (4, e0), (8, s0), (0xc, e0)): c.wr16(si + off, v & 0xffff); c.wr16(si + off + 2, v >> 16)
            c.r['ax'] = c.r['bx'] = 0; return
        p117()
    c.int3 = i3a
    def chop(lay, n_v):
        par(88, 26); par(89, lay)
        m(0xb0, 99, n_v); m(0xb0, 98, 0); m(0xb0, 98, 127)
        A = c.rd16(MAP['CHBANK']); n = c.m[MAP['CHCNT']]
        vs = [c.rd16(MAP['CHV'] + 2 * i) for i in range(n)]
        keys = [(c.m[v + 0xaf], c.m[v + 0xae], c.m[v + 0xb0]) for v in vs]
        bk = [(c.m[A + 0x42 + i], c.m[A + 2 + i], c.m[A + 0x102 + i]) for i in range(n)]
        lp = [(c.rd16(v + 0x12), d32(v + 0x14) & 0x1fffff, d32(v + 8) & 0x1fffff, d32(v + 0x34) & 0x1fffff, d32(v + 0xc) & 0x1fffff, c.rd16(v + 0x54), c.rd16(v + 0x64)) for v in vs]
        return n, keys, bk, lp
    n, k, bk, lp = chop(0, 40)
    res('ONE KEY: C2 up, one key each, bank the same', k == [(36 + i,) * 3 for i in range(n)] and bk == k, str(k[:3]))
    n, k, bk, lp = chop(40, 20)
    w = 61 // n
    res('SPREAD %d slices: %d keys each, own pitch in the middle' % (n, w), k == [(36 + i * w, 36 + i * w + w - 1, 36 + i * w + w // 2) for i in range(n)] and bk == k, str(k))
    res('SPREAD: no loops (source one-shot)', all(x[0] == 0x0808 for x in lp))
    n, k, bk, lp = chop(80, 20)
    res('SPREAD LOOP: every slice a held sustain loop over the whole slice, ending 8 words before the play end', all(lpok(x) for x in lp), str([hex(x[0]) for x in lp]))
    n, k, bk, lp = chop(127, 40)
    last = 36 + (n - 1) + 12
    res('LAST WIDE: others one key each, the last an octave either side', k[:-1] == [(36 + i,) * 3 for i in range(n - 1)] and k[-1] == (last - 12, last + 12, last) and bk == k, str(k[-2:]))
    res('LAST WIDE: only the last looped', all(x[0] == 0x0808 for x in lp[:-1]) and lpok(lp[-1]), str([hex(x[0]) for x in lp]))
except Exception:
    import traceback; traceback.print_exc(); ok = False
print('ALL PASS' if ok else 'SOME FAIL')
