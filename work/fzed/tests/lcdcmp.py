# For every editor control: does FZED40N react, and to the value? Snapshot after boot, then per control: restore,
# set the context (FX type, capture), send the control's messages with a low and a high value, and diff RAM.
import os, json, sys, copy
import numpy as np
V = os.environ.get('VER', 'fzed40n')
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

rows = []      # (row, attribute, text): the ROM text routine always starts at column 0; cx is the attribute (1 = inverse)
prev3 = c.int3
def i3l():
    sp = c.r['sp']; fn = c.rd16(sp)
    if fn == 0xa2:
        a = [c.rd16(sp + 2 * i) for i in range(1, 6)]; p = a[3]
        rows.append((a[1], a[2], bytes(c.m[p:p + 24]).split(b'\0')[0].decode('latin1')))
    prev3()
c.int3 = i3l
def tick(): c.wr16(0x40a, (c.rd16(0x40a) + 0x2000) & 0xffff)
def send1(seq, v):
    for cc, x in seq:
        tick(); midi(c, 0xb0, cc, v if x is None else x); run(c, u, 40000)
    for _ in range(3): tick(); run(c, u, 60000)
base = state()
SKIP = {1549}
only = sys.argv[1:]
out = {}
for d in P:
    k = f"{d['group']}/{d['variant']}/{d['slot']}"
    if only and d['group'] not in only: continue
    if d['code'] in SKIP or not d['sequence']: continue
    restore(base)
    if d['group'] == 'fx':
        FXO = [1,5,14,9,10,3,11,12,13,4,7,6,8,2,0]; v = d["variant"]
        if v >= 0: midi(c, 0xb0, 112, (FXO.index(v) * 128 + 64) // 15); run(c, u, 200000)
    if d['group'].startswith('capture'):
        for cc, x in ((10, 88), (11, 7), (10, 89), (11, 127)): midi(c, 0xb0, cc, x); run(c, u, 60000)
        run(c, u, 600000)
    vals = d['values']; wv = d.get('wireValues') or list(range(128))
    uniq = []
    for i, x in enumerate(vals):
        if not uniq or uniq[-1][0] != x: uniq.append([x, [wv[i]]])
        else: uniq[-1][1].append(wv[i])
    if len(uniq) > 20: pick = [(vals[i], wv[i]) for i in (0, 37, 64, len(wv) - 1)]
    elif d.get('steps') and len(d['steps']) == len(uniq): pick = [(u_[0], wv[s_]) for u_, s_ in zip(uniq, d['steps'])]
    else: pick = [(u_[0], u_[1][len(u_[1]) // 2]) for u_ in uniq]
    res = []
    for lab, raw in pick:
        rows.clear(); send1(d['sequence'], raw); res.append([raw, lab, list(rows)])
    out[k] = dict(label=d['label'], seq=d['sequence'], res=res)
    print(k, d['label'], [(r[0], r[1], [x[2] for x in r[2]][-1:]) for r in res][:3], flush=True)
json.dump(out, open(f'rxout/lcd_{V}{os.environ.get("TAG","")}.json', 'w'), indent=0)
