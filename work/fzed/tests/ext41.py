# FZED41B EXT disk modules: FZED 19 picks a module, Render (CC118) runs it.
#   python3 ext41.py BUILD     (a folder holding fzedflat.bin and fzed.map)
# Checks: module 1 (NOISE) gives exactly the words of a model of its code, on the edit voice; level 0 leaves the
# sample alone; FZED 19 = 0 renders the CC112 effect as before; an empty module slot and a module from another
# build are refused with the sample untouched; a tool module (kind 2) runs once and nothing is rendered after it.
import os, sys, re
T = os.path.dirname(os.path.abspath(__file__))
BUILD = sys.argv[1]
MAP = {}
for l in open(os.path.join(BUILD, 'fzed.map')):
    m = re.match(r'\s+([0-9A-F]+)\s+([0-9A-F]+)\s+(\S+)$', l)
    if m: MAP[m.group(3)] = int(m.group(2), 16)

def boot(patch=None):
    cwd = os.getcwd(); os.chdir(T); sys.path.insert(0, T)
    g = {'__name__': 'x'}
    flat = bytearray(open(os.path.join(BUILD, 'fzedflat.bin'), 'rb').read())
    if patch: patch(flat)
    import tempfile; fp = os.path.join(tempfile.gettempdir(), '_ext41.bin'); open(fp, 'wb').write(flat)
    src = open('tchop.py').read().replace('perf24.bin', fp) \
        .replace("c.codeend=0x8000')", "c.codeend=0xB800')")
    exec(src, g)
    os.chdir(cwd)
    g['c'].ovl = False      # module code must run under the emulator's overlay-signature rule, as on start-up
    return g

def cc(g, n, v): g['midi'](g['c'], 0xb0, n, v); g['run'](g['c'], g['u'], 200000)
def fzed(g, k, v): cc(g, 10, 88); cc(g, 11, k); cc(g, 10, 89); cc(g, 11, v)
def words(g): return [g['wv'](w) for w in range(g['S'], g['E'])]   # the voice's words S..E-1
def render(g): cc(g, 118, 0); cc(g, 118, 127); g['run'](g['c'], g['u'], 6_000_000)
def lcds(g): return [x[2] for x in g['c'].log if x[0] == 'lcd']

def noise_model(src, level_cc, tone_cc):
    lev = 2 * level_cc * level_cc; k = tone_cc * 256 + 255
    x = 0xACE1; y = 0; out = []
    s16 = lambda v: v - 0x10000 if v & 0x8000 else v
    for s in src:
        x ^= (x << 7) & 0xffff; x ^= x >> 9; x ^= (x << 8) & 0xffff
        a = s16(x) >> 1
        d = s16((a - y) & 0xffff)
        p = d * k
        y = s16((y + ((p << 1) >> 16)) & 0xffff)
        n = ((s16((y << 1) & 0xffff) * lev) << 1) >> 16
        r = n + s16(s)
        r = 32767 if r > 32767 else (-32768 if r < -32768 else r)
        out.append(r & 0xffff)
    return out


def eq_model(src, b, m, t, o):
    s16 = lambda v: ((v + 0x8000) & 0xffff) - 0x8000
    def gain(v):
        v &= 0x7f
        return v << 6 if v < 64 else 4096 + (v - 64) * 192
    gB, gM, gT, gO = gain(b), gain(m), gain(t), gain(o)
    def sat(v): return 32767 if v > 32767 else (-32768 if v < -32768 else v)
    L = H = None; out = []
    for w in src:
        x2 = s16(w) >> 1
        if L is None: L = (x2 << 16) & 0xffffffff; H = L
        def one(Y, k):
            y = ((Y >> 16) ^ 0x8000) - 0x8000 if True else 0
            d = s16(x2 - y); p = (d * k) << 1
            Y = (Y + p) & 0xffffffff
            return Y, (((Y >> 16) & 0xffff) ^ 0x8000) - 0x8000
        L, low = one(L, 1671); H, lp3 = one(H, 13356)
        high = s16(x2 - lp3); mid = s16(lp3 - low)
        sm = high * gT + mid * gM + low * gB
        v = sat(sm >> 11); v = sat((v * gO) >> 12)
        out.append(v & 0xffff)
    return out

ok = True
def check(c, msg):
    global ok
    print(('PASS ' if c else 'FAIL ') + msg); ok &= bool(c)

# 1. module 1, level 64, white
g = boot(); before = words(g)
cc(g, 115, 64); cc(g, 116, 127); fzed(g, 19, 12)
check(lcds(g)[-1].rstrip() == 'EXT 01', 'FZED 19 = 12 shows EXT 01 (%r), no disk read' % lcds(g)[-1])
render(g); after = words(g)
L = lcds(g)
check('EXT NOISE' in [x.rstrip() for x in L], 'Render shows the module name (%r)' % L[-3:])
exp = noise_model(before, 64, 127)
diff = [i for i, (a, b) in enumerate(zip(after, exp)) if a != b]
check(not diff, 'NOISE: every word matches the model (%d words, %d differ%s)' % (len(after), len(diff),
      (' first at %d: got %04X want %04X' % (diff[0], after[diff[0]], exp[diff[0]])) if diff else ''))
check(sum(1 for a, b in zip(after, before) if a != b) > len(before) // 2, 'NOISE: the sample really changed')
check(g['c'].rd16(0xD400) == 0x4034 and g['c'].rd16(0xD7BE) == 0x4034, 'the module is still whole in D400h after the render')

# 2. loud samples, full level: peaks clip; then a dark tone
g = boot()
for w in range(g['S'], g['E']):
    v = 0x7800 if w & 1 else 0x8800; g['c'].wave[w * 2] = v & 0xff; g['c'].wave[w * 2 + 1] = v >> 8
before = words(g)
cc(g, 115, 127); cc(g, 116, 127); fzed(g, 19, 8); render(g); after = words(g)
exp = noise_model(before, 127, 127)
check(after == exp and sum(1 for w in exp if w in (0x7fff, 0x8000)) > 100,
      'NOISE level 127 on loud samples: matches the model, full-scale peaks held (%d clipped)' % sum(1 for w in exp if w in (0x7fff, 0x8000)))
g = boot(); before = words(g)
cc(g, 115, 127); cc(g, 116, 10); fzed(g, 19, 8); render(g); after = words(g)
exp = noise_model(before, 127, 10)
check(after == exp, 'NOISE level 127, tone 10: matches the model')

# 3. level 0: unchanged
g = boot(); before = words(g)
cc(g, 115, 0); fzed(g, 19, 8); render(g)
check(words(g) == before, 'NOISE level 0 leaves the sample unchanged')

# 4. FZED 19 back to 0: CC112's effect renders as before (bit mangle vs a run with no FZED 19 at all)
def plain(sel):
    g = boot(); cc(g, 112, 127); cc(g, 113, 40); cc(g, 117, 127)
    if sel: fzed(g, 19, 12); fzed(g, 19, 3)
    render(g); return words(g), lcds(g)[-1]
a, la = plain(False); b, lb = plain(True)
check(a == b and la == lb, 'FZED 19 = 0 again: the CC112 effect renders the same words as without EXT (%r)' % lb)

# 5. empty slot (module 5 = sector 56, past the program): refused, unchanged
g = boot(); before = words(g)
cc(g, 115, 64); fzed(g, 19, 40); render(g)
check(words(g) == before and lcds(g)[-1].rstrip() == 'TOOLS NOT LOADED', 'empty module slot refused (%r), sample unchanged' % lcds(g)[-1])

# 6. a module from another build: refused, unchanged
def other(flat): o = (52 - 17) * 1024 + 4; flat[o] ^= 1
g = boot(other); before = words(g)
cc(g, 115, 64); fzed(g, 19, 8); render(g)
check(words(g) == before and lcds(g)[-1].rstrip() == 'BAD MODULE', 'module from another build refused (%r), sample unchanged' % lcds(g)[-1])

# 7. a tool module (kind 2) in sector 56 (module 5): runs once with si = edit voice, shows its message, renders nothing
def tool(flat):
    o = (56 - 17) * 1024; m = (52 - 17) * 1024
    flat.extend(bytes(o + 0x400 - len(flat)))
    t = bytearray(0x400)
    t[0:2] = (0x4038).to_bytes(2, 'little'); t[2] = 1; t[3] = 2
    t[4:12] = flat[m + 4:m + 12]
    t[0x0C:0x0C + 10] = b'TEST TOOL\x00'
    t[0x20] = 0xF8; t[0x21] = 0xC3                  # init: clc; ret
    code = [0x89, 0x36, 0x40, 0xD5,                 # +23h: mov [D540h],si
            0xFE, 0x06, 0x42, 0xD5,                 # inc byte [D542h]
            0xBB, 0x50, 0xD5]                       # mov bx,D550h
    nm = MAP['NMSG']; at = 0xD423 + len(code) + 3
    code += [0xE9] + list(((nm - at) & 0xffff).to_bytes(2, 'little'))   # jmp NMSG
    t[0x23:0x23 + len(code)] = bytes(code)
    t[0x150:0x150 + 10] = b'TOOL RAN  '; t[0x15A] = 0
    t[0x3BE:0x3C0] = (0x4038).to_bytes(2, 'little')
    flat[o:o + 0x400] = t
g = boot(tool); before = words(g); ev = g['c'].rd16(0xe04)
fzed(g, 19, 40); render(g)
c = g['c']
check(c.m[0xD542] == 1 and c.rd16(0xD540) == ev, 'tool module ran once with si = the edit voice (%d, %04X)' % (c.m[0xD542], c.rd16(0xD540)))
check(lcds(g)[-1].rstrip() == 'TOOL RAN' and words(g) == before, 'tool: its message shows (%r) and nothing was rendered' % lcds(g)[-1])

# 8. EQ (module 2): unity gains give the original less its lowest bit; then a real EQ against the model
g = boot(); before = words(g)
for n, v in ((113, 64), (114, 64), (115, 64), (116, 64)): cc(g, n, v)
fzed(g, 19, 20); render(g); after = words(g)
check(after == [((((w ^ 0x8000) - 0x8000) >> 1) << 1) & 0xffff for w in before] and 'EXT EQ' in [x.rstrip() for x in lcds(g)],
      'EQ, every gain 64: the original back, less the lowest bit (%r)' % lcds(g)[-3:])
for gains in ((127, 64, 0, 64), (0, 127, 20, 100), (90, 30, 127, 40)):
    g = boot()
    for w in range(g['S'], g['E']):
        v = int(9000 * ((w * 37) % 101 - 50) / 50) & 0xffff if w % 3 else (w * 811) & 0xffff
        g['c'].wave[w * 2] = v & 0xff; g['c'].wave[w * 2 + 1] = v >> 8
    before = words(g)
    for n, v in zip((113, 114, 115, 116), gains): cc(g, n, v)
    fzed(g, 19, 20); render(g); after = words(g)
    exp = eq_model(before, *gains)
    d = [i for i, (a, b) in enumerate(zip(after, exp)) if a != b]
    check(not d, 'EQ bass/mid/treble/out %s: every word matches the model (%d differ%s)' % (gains, len(d),
          (' first at %d: got %04X want %04X' % (d[0], after[d[0]], exp[d[0]])) if d else ''))

# 9. BACKUP (module 3): the edit voice into the first empty voice with its own copy of the sample
def winread(c):     # test-model extension (as the live FX harness): DS = 1000h reads the sample window (LVRD)
    o8 = c.rd8
    def rd8(x):
        if c.ds == 0x1000 and c.pfx is None: return c.wave.get(c.wa(x), 0)
        return o8(x)
    c.rd8 = rd8
    c.rd16 = lambda x: rd8(x) | (rd8(x + 1) << 8)
g = boot(); c = g['c']; winread(c); EV = c.rd16(0xe04)
for w in range(g['S'], g['E']):
    v = (w * 2654435761 >> 7) & 0xffff; c.wave[w * 2] = v & 0xff; c.wave[w * 2 + 1] = v >> 8
c.wr16(EV + 0x14, g['S'] + 100); c.wr16(EV + 0x18, g['S'] + 900)   # a loop inside the range
c.wr16(EV + 0x1c, 0x0123); c.wr16(EV + 0x1e, 0x00a0 | 0x0004)       # an address outside it (flags above bit 4 of the high word)
gs = c.rd16(0x80E8) | (c.rd16(0x80EA) << 16); ae = c.rd16(0x80F0) | (c.rd16(0x80F2) << 16)   # GSAVE, AEL, AEH
srcrec = bytes(c.m[EV:EV + 0xc0]); before = words(g)
slots = [0x2288 + 0xc0 * i for i in range(64)]; free = [v for v in slots if c.rd16(v + 0x10) == 0 and v != EV][0]
fzed(g, 19, 24); render(g)
L = lcds(g)
d32 = lambda a: c.rd16(a) | (c.rd16(a + 2) << 16)
new = d32(free + 8) & 0x1fffff
n = (free - 0x2288) // 0xc0 + 1
check('EXT BACKUP' in [x.rstrip() for x in L] and L[-1].rstrip() == 'BACKUP IN V%02d' % n, 'BACKUP shows its name, then BACKUP IN V%02d (%r)' % (n, L[-2:]))
check(c.rd16(0xe04) == EV and words(g) == before and bytes(c.m[EV:EV + 0xc0]) == srcrec, 'the edit voice is still the edit voice, its sample and voice data untouched')
cnt = (ae & 0x1fffff) - (gs & 0x1fffff) + 1; g0 = gs & 0x1fffff
cw = [g['wv'](g0 + i) for i in range(cnt)]; nw = [g['wv'](new + i) for i in range(cnt)]
check(c.rd16(free + 0x10) != 0 and cw == nw, 'the backup (V%02d) has its own copy of the %d words' % (n, cnt))
delta = new - g0; okr = True
for off in range(8, 0xc0):
    pass
def adj(a):
    v = d32(EV + a); ad = v & 0x1fffff
    return ((v & ~0x1fffff) | ((ad + delta) & 0x1fffff)) if g0 <= ad < g0 + cnt else v
exp = {a: adj(a) for a in [8, 0xc] + [0x14 + 4 * k for k in range(16)]}
okr = all(d32(free + a) == v for a, v in exp.items())
okr &= all(c.m[free + a] == srcrec[a] for a in range(0x10, 0x14))
okr &= all(c.m[free + a] == srcrec[a] for a in range(0x54, 0xc0))
check(okr and d32(free + 0x1c) == d32(EV + 0x1c), 'its voice data is the edit voice\'s, with start, end and loop addresses in the range moved to the copy (one outside left alone)')
cc(g, 112, 127); cc(g, 113, 40); cc(g, 117, 127); fzed(g, 19, 0); render(g)
check(words(g) != before and [g['wv'](new + i) for i in range(cnt)] == cw, 'a render on the edit voice afterwards leaves the backup as it was')
g2 = boot(); c2 = g2['c']; winread(c2)
for v in [0x2288 + 0xc0 * i for i in range(64)]:
    if c2.rd16(v + 0x10) == 0: c2.wr16(v + 0x10, 0x1d7)
fzed(g2, 19, 24); render(g2)
check([x[2] for x in c2.log if x[0] == 'lcd'][-1].rstrip() == 'BACKUP: NO SLOT', 'no empty voice: BACKUP: NO SLOT')

# 10. WAVETABLE (module 4): frames x length single cycles from a model, the voice set up for the window and Stretch
FL = open(os.path.join(BUILD, 'fzedflat.bin'), 'rb').read()
def flat16(a): o = (a - 0x6000) if a < 0x8000 else (a - 0x8400 + 0x2000); return FL[o] | (FL[o + 1] << 8)
SQ = [flat16(MAP['SINQ'] + 2 * i) for i in range(65)]
s16 = lambda v: ((v + 0x8000) & 0xffff) - 0x8000
def sinr(k):
    j = k & 127; j = 128 - j if j > 64 else j
    v = SQ[j]; return (-v) & 0xffff if k & 128 else v
def wsin(ph):
    a = sinr(ph >> 8); b = sinr(((ph >> 8) + 1) & 255)
    d = s16((b - a) & 0xffff); f = ph & 255
    return (a + (((d * f) >> 8) & 0xffff)) & 0xffff
def sh(ph, k):
    if k == 0: return wsin(ph)
    if k == 1:
        a = (ph + 0x4000) & 0xffff
        if a & 0x8000: a = (~a) & 0xffff
        return ((a << 1) & 0xffff) ^ 0x8000
    if k == 2: return ph
    return 32767 if ph < 0x8000 else (-32767) & 0xffff
def wtval(ph, ty, m):
    if ty == 0: return wsin(((ph * (7 * m + 256)) >> 8) & 0xffff)
    if ty == 1: return 32767 if ph < 0x8000 - 120 * m else (-32767) & 0xffff
    if ty == 2:
        x = s16(wsin(ph)) >> 3; x = s16(((x * (7 * m + 256)) >> 8) & 0xffff)
        while x > 4095 or x < -4095: x = 8190 - x if x > 4095 else -8190 - x
        return (x << 3) & 0xffff
    pos = 3 * m; i, f = pos >> 8, pos & 255
    t = s16(sh(ph, i)); n = s16(sh(ph, i + 1))
    d = s16(((n >> 1) - (t >> 1)) & 0xffff)
    return (t + s16((((d * f) << 1) >> 8) & 0xffff)) & 0xffff
def table(ty, nf, L, B):
    inc = ((65536 // L) << 16) | (((65536 % L) << 16) // L)
    out = []
    for k in range(nf + 1):
        m = (k if k < nf else nf - 1) * 2 * B // (nf - 1); ph = 0
        for i in range(L if k < nf else 8):
            v = s16(wtval(ph >> 16, ty, m)); out.append((((v * 26214) << 1) >> 16) & 0xffff); ph = (ph + inc) & 0xffffffff
    return out
for ty, fr, ln, sw, label in ((0, 127, 40, 127, 'SYNC 64 x 327'), (1, 70, 0, 90, 'PWM 32 x 164'), (2, 40, 90, 127, 'FOLD 16 x 655'), (3, 10, 127, 127, 'MORPH 8 x 1309')):
    g = boot(); c = g['c']; winread(c); EV = c.rd16(0xe04)
    c.wr16(EV + 0x10, 0)                    # an empty edit voice: new memory, as a preset wave
    for n, v in zip((113, 114, 115, 116), (ty * 32 + 8, fr, ln, sw)): cc(g, n, v)
    fzed(g, 0, 60)                          # Stretch: 5 segments (becomes 8)
    fzed(g, 19, 32); render(g)
    nf = 8 << (fr >> 5); L = (164, 327, 655, 1309)[ln >> 5]; key = (57, 45, 33, 21)[ln >> 5]
    exp = table(ty, nf, L, sw)
    d32 = lambda a: c.rd16(a) | (c.rd16(a + 2) << 16)
    st = d32(EV + 8) & 0x1fffff
    got = [g['wv'](st + i) for i in range(len(exp))]
    bad = [i for i in range(len(exp)) if got[i] != exp[i]]
    L2 = [x[2].rstrip() for x in c.log if x[0] == 'lcd']
    check(not bad and L2[-1] == 'TABLE READY', 'WAVETABLE %s: every word matches the model (%d words, %d differ%s; %r)' % (label, len(exp), len(bad), (' first %d: %04X want %04X' % (bad[0], got[bad[0]], exp[bad[0]])) if bad else '', L2[-1:]))
    voiceok = (d32(EV + 0x14) & 0x1fffff) == st and (d32(EV + 0x34) & 0x1fffff) == st + L and (d32(EV + 0xc) & 0x1fffff) == st + nf * L \
        and c.rd16(EV + 0x12) == 0 and c.rd16(EV + 0xb0) == key and c.m[0xC350 + c.m[0x83C7]] == 127
    N = 2 + ((c.m[0x83FA] * 14) >> 8)
    check(voiceok and N == 8 and c.m[0x83FC] == 128 * 8 // nf - 1 and c.m[0x83FD] == 0 and c.m[0x83FE] == 0 and not c.m[0x83FF] & 0x80,
          'the voice: loop 0 = frame 1, play range = the %d frames, key %d, Window Snap whole frames; Stretch 8 segments, Grain %d, Snap and crossfade off' % (nf, key, c.m[0x83FC]))
    if ty == 3:
        pos = []
        for v in (0, 64, 127):
            cc(g, 10, 4); cc(g, 11, v); g['run'](c, g['u'], 400000)
            pos.append(((d32(EV + 0x14) & 0x1fffff) - st, (d32(EV + 0x34) & 0x1fffff) - (d32(EV + 0x14) & 0x1fffff)))
        check(pos[0] == (0, L) and pos[2] == ((nf - 1) * L, L) and pos[1][0] % L == 0 and pos[1][1] == L and abs(pos[1][0] // L - 64 * (nf - 1) / 127) <= 1, 'Window Position 0 / 64 / 127 moves the loop to whole frames %s' % pos)
    if ty == 0:
        fzed(g, 9, 127); g['run'](c, g['u'], 3_000_000)
        seg = nf * L // 8
        loops = [((d32(EV + 0x14 + 4 * i) & 0x1fffff) - st, (d32(EV + 0x34 + 4 * i) & 0x1fffff) - (d32(EV + 0x14 + 4 * i) & 0x1fffff)) for i in range(8)]
        check(all(o % L == 0 and n == L for o, n in loops) and sorted(o for o, _ in loops) == [i * seg for i in range(8)],
              'Stretch on: its 8 loops each one whole frame, at the start of each segment (%s)' % loops[:3])
g = boot(); c = g['c']; winread(c)
for n, v in zip((113, 114, 115, 116), (8, 127, 127, 127)): cc(g, n, v)
fzed(g, 19, 32); render(g)
check([x[2] for x in c.log if x[0] == 'lcd'][-1].rstrip() == 'TOO BIG', 'a voice whose memory is too small for 64 x 1309: TOO BIG')

print('ALL PASS' if ok else 'SOME FAILED')
