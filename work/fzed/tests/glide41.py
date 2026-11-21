# FZED41I Window Snap GLIDE and LFO 2 SLOW.
#   python3 glide41.py BUILD     (a folder holding fzedflat.bin and fzed.map)
# Checks: a WAVETABLE (64 frames of 82 words) sets Window Snap to GLIDE; a jump of Window Position from 0 to 127 then
# walks the loop through every frame in turn (none skipped, none repeated backwards), each step at least 3 x 82 timer
# units after the last, and it gets to the last frame with no further control moves; back to 0 likewise; WHOLE FRAMES
# (Window Snap 96) still jumps straight there. LFO 2 FREE SLOW runs a sixteenth of FREE's speed at the same rate, and
# RETRIGGER SLOW too; the old FREE / RETRIGGER / MIDI CLOCK values give their old modes.
import os, sys
os.environ['FZTIMER'] = '1'
T = os.path.dirname(os.path.abspath(__file__))
sys.argv = [sys.argv[0], sys.argv[1]]
src = open(os.path.join(T, 'ext41.py')).read().split('ok = True')[0]
exec(src)
ok = True
def check(c, msg):
    global ok
    print(('PASS ' if c else 'FAIL ') + msg); ok = ok and c

def winread(c):     # as ext41.py: DS = 1000h reads the sample window (LVRD)
    o8 = c.rd8
    def rd8(x):
        if c.ds == 0x1000 and c.pfx is None: return c.wave.get(c.wa(x), 0)
        return o8(x)
    c.rd8 = rd8
    c.rd16 = lambda x: rd8(x) | (rd8(x + 1) << 8)
g = boot(); c = g['c']; winread(c); EV = c.rd16(0xe04)
c.wr16(EV + 0x10, 0)
for n, v in zip((113, 114, 115, 116), (3 * 32 + 8, 127, 0, 127)): cc(g, n, v)   # MORPH, 64 frames, 82 words
fzed(g, 19, 32); render(g)
L = 82; NF = 64
d32 = lambda a: c.rd16(a) | (c.rd16(a + 2) << 16)
st = d32(EV + 8) & 0x1fffff
snap = c.m[0xC350 + c.m[0x83C7]]
check(snap == 127, 'WAVETABLE sets Window Snap to GLIDE (127): %d' % snap)
def frame(): return ((d32(EV + 0x14) & 0x1fffff) - st) // L
def walk(target, budget=40000000, step=4000):
    seen = [(frame(), c.rd16(0x40a))]; n = 0
    while n < budget:
        g['run'](c, g['u'], step); n += step
        f = frame()
        if f != seen[-1][0]: seen.append((f, c.rd16(0x40a)))
        if f == target and n > 400000: break
    return seen
cc(g, 10, 4); cc(g, 11, 0); g['run'](c, g['u'], 2000000)
check(frame() == 0, 'Window Position 0: frame 0 (%d)' % frame())
cc(g, 10, 4); c.log.clear(); g['midi'](c, 0xb0, 11, 127)
up = walk(NF - 1)
fr = [f for f, _ in up]
gaps = [(up[i + 1][1] - up[i][1]) & 0xffff for i in range(1, len(up) - 1)]
check(fr == list(range(fr[0], NF)) and fr[0] <= 1 and fr[-1] == NF - 1, 'up 0 -> 127: every frame in turn to the last (%d steps, %s ... %s)' % (len(fr), fr[:4], fr[-3:]))
check(gaps and min(gaps) >= 3 * L, 'each step at least one frame cycle (3 x %d = %d units) after the last: shortest %d, longest %d' % (L, 3 * L, min(gaps) if gaps else -1, max(gaps) if gaps else -1))
g['midi'](c, 0xb0, 11, 0)
dn = walk(0)
fr = [f for f, _ in dn]
check(fr == list(range(fr[0], -1, -1)) and fr[0] >= NF - 2 and fr[-1] == 0, 'down 127 -> 0: every frame in turn back to the first (%d steps)' % len(fr))
cc(g, 10, 3); cc(g, 11, 96)                 # Window Snap WHOLE FRAMES
cc(g, 10, 4); g['midi'](c, 0xb0, 11, 127); g['run'](c, g['u'], 300000)
check(frame() == NF - 1, 'WHOLE FRAMES (96): straight to the last frame (%d)' % frame())
# LFO 2 SLOW
def lfo_speed(mode_v, rate=8):
    cc(g, 92, 16); cc(g, 89, rate); cc(g, 93, mode_v)
    p0 = c.rd16(0x81A8); t0 = c.rd16(0x40a); tot = 0; last = p0
    for _ in range(100):
        g['run'](c, g['u'], 20000)
        p = c.rd16(0x81A8); tot += (p - last) & 0xffff; last = p
    t = (c.rd16(0x40a) - t0) & 0xffff
    return tot / max(t, 1), c.m[0x81A4], c.m[0x81BB]
fr_, m0, s0 = lfo_speed(13)
fs_, m1, s1 = lfo_speed(39)
rr_, m2, s2 = lfo_speed(64)
rs_, m3, s3 = lfo_speed(90)
ck_, m4, s4 = lfo_speed(127)
check((m0, s0, m1, s1, m2, s2, m3, s3, m4, s4) == (0, 0, 0, 1, 1, 0, 1, 1, 2, 0), 'Mode bands: FREE, FREE SLOW, RETRIGGER, RETRIGGER SLOW, MIDI CLOCK %s' % ((m0, s0, m1, s1, m2, s2, m3, s3, m4, s4),))
check(fr_ > 0 and 13 <= fr_ / max(fs_, 1e-9) <= 19, 'FREE SLOW a sixteenth of FREE: %.4f vs %.4f a unit (x%.1f)' % (fs_, fr_, fr_ / max(fs_, 1e-9)))
check(rr_ > 0 and 13 <= rr_ / max(rs_, 1e-9) <= 19, 'RETRIGGER SLOW a sixteenth of RETRIGGER (x%.1f)' % (rr_ / max(rs_, 1e-9)))
for v, m in ((21, 0), (64, 1), (106, 2)):
    cc(g, 93, v)
    check(c.m[0x81A4] == m and c.m[0x81BB] == 0, 'old value %d still gives mode %d, not slow' % (v, m))
print('ALL PASS' if ok else 'SOME FAIL')
