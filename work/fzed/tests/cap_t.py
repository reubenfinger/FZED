# PERF38P capture mode: ROM key queue modelled (API51 writes it, API6 takes ONE event per call) in the emulator: overlay load, cycles, controls, sync, leaving. Record generators "stop" after
# the take's length in time (words / rate).
import sys, re
src = open('tchop.py').read().replace('perf24.bin', 'perf38tflat.bin').replace("c.codeend=0x8000')", "c.codeend=0xB800')")
exec(src.split("run(c,u,3_000_000)")[0])
c.ovl = True
MAP = {}
for l in open('perf38t.map'):
    p = l.split()
    if len(p) in (2, 3) and re.fullmatch(r'[0-9A-F]{4,8}', p[0]):
        try: MAP[p[-1]] = int(p[1] if len(p) == 3 else p[0], 16)
        except ValueError: pass
def M16(a): return c.m[a] | (c.m[a + 1] << 8)
st = {'rec0': None, 'recw': 0, 'seq': [], 'sp': [], 'rate': 0}
capprev = c.int3
def i3():
    sp = c.r['sp']; fn = c.rd16(sp); a = [c.rd16(sp + 2 * i) for i in range(1, 5)]
    if fn not in (6, 0xa2): st['sp'].append((fn, sp))
    if fn == 0x33:
        w = c.m[0xbe0]
        for b in (a[0], a[1], a[2]): c.m[0xade + w] = b & 0xff; w = (w + 1) & 0xff
        c.m[0xbe0] = w
    if fn == 6:
        if c.m[0xbde] != c.m[0xbe0]:
            if st['rec0'] is not None: st['bad'] = st.get('bad', 0) + 1
            c.m[0xbde] = (c.m[0xbde] + 3) & 0xff
        if st['rec0'] is not None: st['k6rec'] = st.get('k6rec', 0) + 1
    if fn == 0xbf: st['seq'].append(('load', a[0], hex(a[1])))
    if fn == 117: st['seq'].append(('alloc', a[2]))
    if fn == 119: st['seq'].append('del')
    if fn == 45:
        st['seq'].append(('rs', a[2])); v = a[0]
        st['recw'] = (M16(v + 0xc) | ((M16(v + 0xe) & 0x1f) << 16)) - (M16(v + 8) | ((M16(v + 0xa) & 0x1f) << 16))
    if fn == 46:
        st['rec0'] = c.steps; st['mute'] = c.m[0x46d] & 0x20; c.r['ax'] = c.r['bx'] = 0; return
    if fn == 47: st['seq'].append(('stop', a[2]))
    if fn == 49:
        ms = st['recw'] / (36 >> c.m[0x4d9])
        busy = st['rec0'] is not None and (c.steps - st['rec0']) * 32 / 200 < ms * 103.68
        c.r['ax'] = c.r['bx'] = 1 if busy else 0
        if not busy: st['rec0'] = None
        return
    if fn == 0x33: st['seq'].append(('on' if a[0] == 0x90 else 'off', a[1], c.steps, a[2]))
    capprev()
c.int3 = i3
run(c, u, 3_000_000)
def cc(n, v, t=200000):
    sp = c.pfx; c.pfx = None
    if n == 108 and v >= 64 and 'CAPIN' in MAP and c.m[MAP['CAPON']] == 0 and c.m[MAP['RST']] != 1:
        for b in ((10, 88), (11, 7), (10, 89), (11, 127)): midi(c, 0xb0, *b)   # PERF40K: capture mode is control 7 (Gills' CAPTURE view)
    else: midi(c, 0xb0, n, v)
    c.pfx = sp; run(c, u, t)
def lcd(n=1): return [x[2] for x in c.log if x[0] == 'lcd'][-n:]
def notes(): return [x for x in st['seq'] if isinstance(x, tuple) and x[0] in ('on', 'off')]

def ms(steps): return round(steps * 32 / 200 / 103.68)
def cycle():  # first chord after the last capture: keys, velocities, start offsets (ms), hold (ms, last off - first on)
    ns = notes()
    i = max(j for j, x in enumerate(ns) if x[0] == 'on' and (j == 0 or ns[j-1][0] == 'off')) if ns else 0
    return ns
def chords():
    ns = notes(); out = []; cur = None
    for x in ns:
        if x[0] == 'on':
            if cur is None or cur['done']: cur = {'on': [], 'off': [], 'done': False}; out.append(cur)
            cur['on'].append(x)
        else:
            if cur: cur['off'].append(x); cur['done'] = len(cur['off']) == len(cur['on'])
    res = []
    for ch in out:
        if not ch['done']: continue
        t0 = ch['on'][0][2]
        res.append(dict(keys=[x[1] for x in ch['on']], vel=[x[3] for x in ch['on']], starts=[ms(x[2]-t0) for x in ch['on']], hold=ms(ch['off'][-1][2]-t0)))
    return res

EV = M16(0xe04)
def chords2():
    ns = notes(); out = []; cur = None
    for x in ns:
        if x[0] == 'on':
            if cur is None or cur['done']: cur = {'on': [], 'off': [], 'done': False}; out.append(cur)
            cur['on'].append(x)
        else:
            if cur: cur['off'].append(x); cur['done'] = len(cur['off']) == len(cur['on'])
    return [dict(keys=[x[1] for x in ch['on']], starts=[ms(x[2]-ch['on'][0][2]) for x in ch['on']], hold=ms(ch['off'][-1][2]-ch['on'][0][2])) for ch in out if ch['done']]
cc(102, 64); cc(103, 5 * 8); cc(105, 0)          # 100 ms, 1 pass
cc(108, 127, 2_000_000)
for sg in (8, 15):
    cc(96, 5 * 128 // 9 + 3); cc(99, sg * 8)
    print('stagger step', sg, 'LCD', lcd(1))
    st['seq'] = []; run(c, u, 40_000_000)
    print('  chords:', chords2()[1:2], 'raw', [(x[0],x[1],ms(x[2]-notes()[0][2])) for x in notes()[:10]])
