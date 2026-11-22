# FZED41J STRETCH NEXT: JOIN (each loop starts where the last one ends) and Sample Start moving the joined loops;
# NEXT in 6 bands with the old TRACE / CUT / SKIP / CUT values (and the editor's steps 16 / 48 / 80 / 112) as before.
#   VER=fzed python3 join41.py   (fzedflat.bin and fzed.map here)
import os
V = os.environ.get('VER', 'fzed')
exec(open('romfix.py').read())
src = romfix(open('cap_t.py').read()).replace('perf38t', V)
exec(src.split("cc(102, 64); cc(103, 5 * 8)")[0])
loads = []
prev3 = c.int3
def i3s():
    sp = c.r['sp']; fn = c.rd16(sp)
    if fn == 0xbf: loads.append(c.rd16(sp + 2))
    prev3()
c.int3 = i3s
def m(*b): midi(c, *b); run(c, u, 250000)
lcds = lambda: [x[2] for x in c.log if x[0] == 'lcd' and not x[2].startswith(('C=', 'P='))]
def stc(k, v): m(0xb0, 10, 88); m(0xb0, 11, k); m(0xb0, 10, 89); m(0xb0, 11, v)
def res(name, ok, info=''): print(('PASS ' if ok else 'FAIL ') + name, info)
d32 = lambda a: c.rd16(a) | ((c.rd16(a + 2) & 0x1f) << 16)
def sdiv(a, b): q = abs(a) // abs(b); return q if (a < 0) == (b < 0) else -q
ok = True
def chk(name, c_, info=''):
    global ok
    res(name, c_, info); ok = ok and c_
try:
    si = c.rd16(0xe04)
    c.wr16(si, 0x1000); c.wr16(si + 4, 0x2008)
    S, E = d32(si + 8), d32(si + 0xc)
    m(0xb0, 86, 64)
    stc(4, 0); stc(0, 127); stc(1, 64); stc(2, 15); stc(3, 10); stc(9, 127)
    N = 8; seg = (E - S) // N; g = max(32, (seg * 16) >> 7)
    lp = lambda: [(d32(si + 0x14 + 4 * i), d32(si + 0x34 + 4 * i)) for i in range(N)]
    nxt = lambda: [c.m[si + 0x37 + 4 * i] & 0x80 for i in range(8)]
    chk('TRACE (as before): loops at the segment starts', lp() == [(S + i * seg, S + i * seg + g) for i in range(N)], str([hex(a) for a, b in lp()[:3]]))
    for v, want, name in ((0, 0, 'TRACE'), (16, 0, 'TRACE'), (40, 0x10, 'JOIN'), (48, 0x20, 'TRACE, CUT'), (80, 0x40, 'SKIP'), (100, 0x30, 'JOIN, CUT'), (112, 0x60, 'SKIP, CUT'), (127, 0x60, 'SKIP, CUT')):
        stc(16, v); chk('NEXT %d: %s' % (v, name), c.m[0x801A] == want, hex(c.m[0x801A]))
    stc(16, 40)
    chk('JOIN: each loop starts where the last ends (a grain apart), trace', lp() == [(S + i * g, S + (i + 1) * g) for i in range(N)] and nxt() == [0] * 8, str([(hex(a), hex(b)) for a, b in lp()[:3]]))
    chk('JOIN: the 8 grains cover the first 8 x grain (%d of %d words)' % (8 * g, E - S), d32(si + 0x34 + 4 * 7) == S + 8 * g)
    loads.clear(); m(0xb0, 76, 40)
    S2 = d32(si + 8)
    chk('JOIN: Sample Start moves the start (%x -> %x)' % (S, S2), S2 > S)
    chk('JOIN: and the joined loops are built again from it', lp() == [(S2 + i * g2, S2 + (i + 1) * g2) for g2 in [max(32, (((E - S2) // N) * 16) >> 7)] for i in range(N)], str([(hex(a), hex(b)) for a, b in lp()[:2]]) + ' loads %s' % loads)
    m(0xb0, 76, 0); stc(16, 0)
    before = lp(); m(0xb0, 76, 40)
    chk('TRACE: Sample Start leaves the loops alone (as before)', lp() == before)
    m(0xb0, 76, 0); stc(16, 112)
    chk('SKIP, CUT LEAD-IN: skip bits back on each loop end', nxt() == [0x80] * 8)
except Exception as e:
    import traceback; traceback.print_exc(); ok = False
print('ALL PASS' if ok else 'SOME FAIL')
