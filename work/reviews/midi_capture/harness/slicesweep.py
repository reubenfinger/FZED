# t2 with chop slices: chop CC99 slices of the test voice first (127 = 32 slices), then sweep knobs. Reports CC timing,
# the longest gap between key checks, and (OUT=file.json) the CCs applied and every slice's settings, to compare builds.
# usage: SHARE=0.29 python3 -I slicesweep.py BUILD CC99 KNOBS RATE SECS   (MH = the harness folder, default this one)
import os, sys
H = os.environ.get('MH') or os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, H)
import mh
bd = sys.argv[1]; c99 = int(sys.argv[2]); knobs = int(sys.argv[3]); rate = float(sys.argv[4]); secs = float(sys.argv[5])
share = float(os.environ.get('SHARE', '0.29'))
h = mh.M(bd, n=4096); c = h.c
nxt = [0x30000]; p117 = c.int3
def i3a():
    sp = c.r['sp']; fn = c.rd16(sp); a = [c.rd16(sp + 2 * i) for i in range(1, 5)]
    if fn == 117 and a[3] == 0 and a[2] < 4096:
        si = a[0]; s0 = nxt[0]; e0 = s0 + a[2]; nxt[0] = e0 + 16
        for off, vv in ((0, s0), (4, e0), (8, s0), (0xc, e0)): c.wr16(si + off, vv & 0xffff); c.wr16(si + off + 2, vv >> 16)
        c.r['ax'] = c.r['bx'] = 0; return
    p117()
c.int3 = i3a
for cc_, vv in ((97, 0), (99, c99), (98, 0), (98, 127)): h.cc(cc_, vv, 3_000_000)
M = h.MAP; cnt = c.m[M['CHCNT']]
h.to_loop(); CPS = 8e6 * share
ccs = [74, 75, 71, 73, 78, 79][:knobs]; ev = []; n = int(rate * secs)
for k, cc in enumerate(ccs):
    for i in range(n):
        t = (i + k / knobs) / rate * CPS; v = (i * 3 + 7 * k) % 128
        ev.append((t, [0xb0, cc, v], (cc, v)))
h.stream(ev); h.watch_dispatch(); h.reset_counts(); h.t0 = 0
maxpend = 0; lastp = [h.v30]; gaps = []
def pg(hh):
    if hh.c.ip == hh.lp: gaps.append(hh.v30 - lastp[0]); lastp[0] = hh.v30
h.hooks.append(pg)
while h.v30 < secs * CPS * 1.4:
    h.step(); p = h.pending()
    if p > maxpend: maxpend = p
sent = [(t, tag) for t, tag, lap in h.sent]; got = h.got
si = 0; waits = []; wrong = 0; lost = 0
for t, cc, v in got:
    j = si
    while j < len(sent) and sent[j][1] != (cc, v): j += 1
    if j == len(sent): wrong += 1; continue
    lost += j - si; waits.append((t - sent[j][0]) / CPS); si = j + 1
# CHPROP: every slice's sound settings (54h..ADh) equal the source voice's
src = c.rd16(0xe04)
print('build %s  slices %d  %d knobs x %g/s  at %.0f%%' % (os.path.basename(bd), cnt, knobs, rate, share * 100))
p = h.acc['pass']
print('  passes %d, clocks per pass %.0f; applied %d of %d, mis-parsed %d, skipped %d, largest backlog %d' % (p[0], p[1] / max(1, p[0]), len(got), len(sent), wrong, lost, maxpend))
print('  longest gap between key checks %.0f ms' % (max(gaps) / CPS * 1000))
if waits: print('  wait median %.0f ms, max %.0f ms' % (sorted(waits)[len(waits) // 2] * 1000, max(waits) * 1000))
print('  source voice 54h..ADh:', bytes(c.m[src + 0x54:src + 0xae]).hex()[:40], '...')
import hashlib, json
chv = M['CHV']; vs = [src] + [c.rd16(chv + 2 * k) for k in range(cnt)]
json.dump({'got': [(cc, v) for t, cc, v in got], 'low': hashlib.md5(bytes(c.m[0:0x6000])).hexdigest(), 'vox': [bytes(c.m[a:a + 0xc0]).hex() for a in vs]}, open(os.environ.get('OUT', '/dev/null'), 'w'))
