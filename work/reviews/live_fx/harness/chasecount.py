# count chase and sweep chunks per main-loop pass with a playhead moving STEP words per pass
# python3 -I chasecount.py BUILD STEP   (BUILD = a folder with fzed.lst / fzedflat.bin; STEP = playhead words per pass)
import sys, os
H = sys.argv[3] if len(sys.argv) > 3 else os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, H)
os.environ['FZTIMER'] = '1'
import lvh, sig
bd, STEP = sys.argv[1], int(sys.argv[2])
N = 3072
h = lvh.H(bd, signal=sig.signal(), timing=False); c = h.c; g = h.g; M = h.MAP
EV = g['EV']; c.wr16(EV + 12, h.S + N - 1); h.E = h.S + N
lp = h.addr('MAIN', 'call L6372'); chase_call = h.addr('LVRUN', 'call LVCHK', 1); sweep_call = h.addr('LVRUN', 'call LVCHK', 2)
passes = [0]; cnt = {'chase': 0, 'sweep': 0}; on = [False]
def step():
    if c.ip == lp:
        passes[0] += 1
        ph = h.S + (passes[0] * STEP) % N
        c.m[0x5420] = 1; c.wr16(0x5420 + 0xa, EV); h.u.mem = getattr(h.u, 'mem', {}); h.u.mem[2] = ph & 0xffff; h.u.mem[4] = ph >> 16
    if on[0]:
        if c.ip == chase_call: cnt['chase'] += 1
        if c.ip == sweep_call: cnt['sweep'] += 1
    h.step()
def until(pred, limit):
    k = 0
    while not pred():
        step(); k += 1
        if k > limit: return False
    return True
def ccp(n, v, np=6):
    until(lambda: c.ip == lp, 10_000_000); h.cc(n, v, 0); p = passes[0]; until(lambda: passes[0] - p >= np, 30_000_000)
ccp(112, 13, 12); ccp(117, 127, 12); ccp(119, 127, 4)
until(lambda: c.m[M['LVON']] == 2 and c.m[M['LVDIRTY']] == 0, 20_000_000)
on[0] = True; p0 = passes[0]
until(lambda: passes[0] - p0 >= 200, 200_000_000)
print('step %d words/pass: chase %d sweep %d in 200 passes' % (STEP, cnt['chase'], cnt['sweep']))
