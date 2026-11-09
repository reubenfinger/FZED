# For every editor control: does FZED40N react, and to the value? Snapshot after boot, then per control: restore,
# set the context (FX type, capture), send the control's messages with a low and a high value, and diff RAM.
import os, json, sys, copy
import numpy as np
V = os.environ.get('VER', 'fzed')
exec(open('romfix.py').read())
src = romfix(open('cap_t.py').read()).replace('perf38t', V)
exec(src.split("run(c, u, 3_000_000)")[0])
EV0 = c.rd16(0xe04)
for o in range(0xb2, 0xbe): c.m[EV0 + o] = ord('MY SAMPLE   '[o - 0xb2])
run(c, u, 3_000_000)
SYM = sorted((v, k) for k, v in MAP.items() if 0 <= v < 0x10000)
def name(a):
    if 0x2288 <= a < 0x2288 + 64 * 0xc0:
        n, o = divmod(a - 0x2288, 0xc0); return f'voice{n}+{o:02X}'
    best = None
    for v, k in SYM:
        if v <= a: best = (v, k)
        else: break
    return f'{best[1]}+{a - best[0]:X}' if best and a - best[0] < 0x40 else f'{a:04X}'
P = json.load(open('rxout/profile_new.json'))['controls']
SKIPK = ('log', 'api', 'writes')
def state(): return (copy.deepcopy({k: v for k, v in c.__dict__.items() if k not in SKIPK}), copy.deepcopy(st))
def restore(s):
    c.__dict__.update(copy.deepcopy(s[0])); st.clear(); st.update(copy.deepcopy(s[1])); c.log.clear()
def send(seq, v):
    for cc, x in seq:
        midi(c, 0xb0, cc, v if x is None else x); run(c, u, 40000)
    run(c, u, 150000)
if os.environ.get('CHOP'):
    ev0 = c.rd16(0xe04); c.wr16(ev0, 0x1000); c.wr16(ev0 + 4, 0x2008)
    for o, vv in ((8, 0x1000), (0xc, 0x9000)): c.wr16(ev0 + o, vv)
    nxt = [0x30000]; p117 = c.int3
    def i3a():
        sp = c.r['sp']; fn = c.rd16(sp); a = [c.rd16(sp + 2 * i) for i in range(1, 5)]
        if fn == 117 and a[2] == 1816 and a[3] == 0:
            si = a[0]; s0 = nxt[0]; e0 = s0 + 1816; nxt[0] = e0 + 16
            for off, vv in ((0, s0), (4, e0), (8, s0), (0xc, e0)): c.wr16(si + off, vv & 0xffff); c.wr16(si + off + 2, vv >> 16)
            c.r['ax'] = c.r['bx'] = 0; return
        p117()
    c.int3 = i3a
    for cc_, vv in ((97, 0), (99, 48), (98, 0), (98, 127)): midi(c, 0xb0, cc_, vv); run(c, u, 600000)
    print('chopped', c.m[MAP['CHCNT']], [x[2] for x in c.log if x[0] == 'lcd'][-2:])
# noise: what changes with no message at all
base = state(); a0 = np.frombuffer(bytes(c.m), np.uint8).copy(); run(c, u, 400000); noise = set(np.nonzero(np.frombuffer(bytes(c.m), np.uint8) != a0)[0].tolist())
restore(base); run(c, u, 400000); a1 = np.frombuffer(bytes(c.m), np.uint8).copy(); run(c, u, 400000)
noise |= set(np.nonzero(np.frombuffer(bytes(c.m), np.uint8) != a1)[0].tolist())
restore(base)
fxv = {}
for d in P:
    if d['group'] == 'fx' and d['code'] == 112: fxv = d
SKIP = {1549}       # EXIT FZED leaves the program: checked on its own
out = {}
only = sys.argv[1:] 
for d in P:
    k = f"{d['group']}/{d['variant']}/{d['slot']}"
    if only and d['group'] not in only: continue
    if d['code'] in SKIP: continue
    restore(base)
    if d['group'] == 'fx':      # pick the effect this variant belongs to
        raws = [r for r in range(128) if d.get('fxVariantOf') is None]
        FXO = [1,5,14,9,10,3,11,12,13,4,7,6,8,2,0]; v = d["variant"]; midi(c, 0xb0, 112, (FXO.index(v) * 128 + 64) // 15 if v >= 0 else 0); run(c, u, 200000)
    if d['group'].startswith('capture'):
        for cc, x in ((10, 88), (11, 7), (10, 89), (11, 127)): midi(c, 0xb0, cc, x); run(c, u, 60000)
        run(c, u, 600000)
    seq = d['sequence']
    if not seq: out[k] = dict(label=d['label'], note='no messages'); continue
    lo, hi = (d['wireValues'][0], d['wireValues'][-1]) if d.get('wireValues') else (0, 127)
    s0 = np.frombuffer(bytes(c.m), np.uint8).copy()
    send(seq, lo); s1 = np.frombuffer(bytes(c.m), np.uint8).copy()
    send(seq, hi); s2 = np.frombuffer(bytes(c.m), np.uint8).copy()
    anych = [a for a in np.nonzero((s1 != s0) | (s2 != s0))[0].tolist() if a not in noise]
    valch = [a for a in np.nonzero(s2 != s1)[0].tolist() if a not in noise]
    out[k] = dict(label=d['label'], code=d['code'], seq=seq, lo=lo, hi=hi, value=valch, any=anych, nval=len(valch), nany=len(anych))
    print(k, d['label'], 'VALUE' if valch else ('ANY' if anych else 'NONE'), [name(a) for a in (valch or anych)[:4]], flush=True)
json.dump(out, open(f'rxout/rxscan_{V}{os.environ.get("TAG","")}.json', 'w'), indent=0)
