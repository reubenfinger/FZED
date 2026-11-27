# RH10: the matrix moves the loop window on every pass its value changes (about 1.2 ms), outside the 15 ms turns of
# the other slow destinations; those keep their pacing.
#   python3 winfast.py BUILD [BASE]   (folders holding fzedflat.bin and fzed.map; BASE: an older build to compare)
import os, sys
os.environ['FZTIMER'] = '1'
T = os.path.dirname(os.path.abspath(__file__))
builds = sys.argv[1:]
def measure(build):
    sys.argv = [sys.argv[0], build]
    g0 = {'__file__': os.path.join(T, 'x.py'), '__name__': 'x'}
    exec(open(os.path.join(T, 'ext41.py')).read().split('ok = True')[0], g0)
    g = g0['boot'](); c = g['c']; cc = g0['cc']
    D = lambda a: c.m[a] | (c.m[a + 1] << 8) | ((c.m[a + 2] & 0x1f) << 16)
    cc(g, 88, 64); cc(g, 89, 127); cc(g, 90, 127); cc(g, 91, 0); cc(g, 93, 0)     # LFO 2: fast, full depth
    for p, v in ((90, 32), (100, 127), (110, 72),          # route 1: LFO 2 -> LOOP WINDOW, +63
                 (91, 32), (101, 127), (111, 64)):         # route 2: LFO 2 -> SAMPLE START, +63
        cc(g, 10, p); cc(g, 11, v)
    g['midi'](c, 0x90, 60, 100)                        # a note held (LFO 2 runs with it)
    si = c.rd16(0xe04); w0 = D(si + 0x14); s0 = D(si + 8); nw = ns = 0
    t0 = c.rd16(0x40a); ticks = 0; last = t0
    for k in range(3000):
        g['run'](c, g['u'], 648)
        t = c.rd16(0x40a); ticks += (t - last) & 0xffff; last = t
        w = D(si + 0x14); s = D(si + 8)
        if w != w0: nw += 1; w0 = w
        if s != s0: ns += 1; s0 = s
    return nw, ns
ok = True
new = measure(builds[0]); print('new : window moves %d, sample-start moves %d' % new)
if len(builds) > 1:
    old = measure(builds[1]); print('base: window moves %d, sample-start moves %d (same run length)' % old)
    r = new[0] / max(old[0], 1)
    print(('PASS' if r >= 1.5 else 'FAIL') + ' the window moves %.1f times as often' % r); ok = ok and r >= 1.5
    print(('PASS' if new[1] <= old[1] * 1.2 + 2 else 'FAIL') + ' sample start keeps its 15 ms turns (%d vs %d)' % (new[1], old[1])); ok = ok and new[1] <= old[1] * 1.2 + 2
print('ALL PASS' if ok else 'SOME FAIL')
