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

# 5. empty slot (module 2 = sector 53, blank): refused, unchanged
g = boot(); before = words(g)
cc(g, 115, 64); fzed(g, 19, 16); render(g)
check(words(g) == before and lcds(g)[-1].rstrip() == 'TOOLS NOT LOADED', 'empty module slot refused (%r), sample unchanged' % lcds(g)[-1])

# 6. a module from another build: refused, unchanged
def other(flat): o = (52 - 17) * 1024 + 4; flat[o] ^= 1
g = boot(other); before = words(g)
cc(g, 115, 64); fzed(g, 19, 8); render(g)
check(words(g) == before and lcds(g)[-1].rstrip() == 'EXT: BAD MODULE', 'module from another build refused (%r), sample unchanged' % lcds(g)[-1])

# 7. a tool module (kind 2) in sector 53: runs once with si = edit voice, shows its message, renders nothing
def tool(flat):
    o = (53 - 17) * 1024; m = (52 - 17) * 1024
    t = bytearray(0x400)
    t[0:2] = (0x4035).to_bytes(2, 'little'); t[2] = 1; t[3] = 2
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
    t[0x3BE:0x3C0] = (0x4035).to_bytes(2, 'little')
    flat[o:o + 0x400] = t
g = boot(tool); before = words(g); ev = g['c'].rd16(0xe04)
fzed(g, 19, 16); render(g)
c = g['c']
check(c.m[0xD542] == 1 and c.rd16(0xD540) == ev, 'tool module ran once with si = the edit voice (%d, %04X)' % (c.m[0xD542], c.rd16(0xD540)))
check(lcds(g)[-1].rstrip() == 'TOOL RAN' and words(g) == before, 'tool: its message shows (%r) and nothing was rendered' % lcds(g)[-1])

print('ALL PASS' if ok else 'SOME FAILED')
