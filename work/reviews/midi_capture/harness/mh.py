# MIDI / capture review harness: boots a build in the repo's emulator (through the live FX harness, lvh.py) and
# times the stages of the main loop.  usage: import mh; h = mh.M(builddir)
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
LV = os.environ.get('LVH') or os.path.normpath(os.path.join(HERE, '..', '..', 'live_fx', 'harness'))
sys.path.insert(0, LV)
os.environ.setdefault('FZTIMER', '1')
import lvh, sig, bus, cyc
STAGES = ['L6372', 'CAPTICK', 'MATRIX', 'RVPATCH', 'LVRUNX', 'PARSE', 'MROUTE', 'DISPATCH', 'ECHOF', 'ENDW']
class M(lvh.H):
    def __init__(s, bdir, timing=True, n=1536):
        lvh.H.__init__(s, bdir, signal=sig.signal(), timing=timing)
        c = s.c; s.N = n
        EV = s.g['EV']; c.wr16(EV + 12, s.S + n - 1); s.E = s.S + n
        s.lp = s.addr('MAIN', 'call L6372')
        s.passes = 0; s.stage = {}
        for st in STAGES:
            a = s.addr('MAIN', 'call ' + st); s.stage[st] = a
            s.span(st, a, a + s.lst[a][1])
        s.span('pass', s.lp, s.lp)
        s.hooks = []                      # callables run before every instruction: f(h)
        s.bus = bus.Bus()                 # bus-limited estimate: its clock total replaces lvh's 8086 column (acc[..][2])
    def step(s):
        if s.c.ip == s.lp: s.passes += 1
        for f in s.hooks: f(s)
        if not s.timing: lvh.H.step(s); return
        c = s.c; ip = c.ip; e = s.lst.get(ip); cx = c.r['cx']; es = c.es; i0 = s.i86
        lvh.H.step(s)
        if e is not None:
            txt, ln = e
            try:
                taken = c.ip != ((ip + ln) & 0xffff)
                v = cyc.cost(txt, taken=taken, n=cx, cl=cx)[0]
                t0 = s.bus.t
                code = txt.split(';')[0]
                s.bus.ins(ln, v, bus.data_cycles(txt, cx), taken and bus.flow(txt), wave=(es == 0x1000 and ('es:' in code or 'movs' in code or 'stos' in code)) or ('movs' in code and c.ds == 0x1000), io=bool(__import__('re').match(r'\s*(\.?\w+:\s*)?(in|out)\b', code)))
                s.i86 = i0 + (s.bus.t - t0)
            except cyc.Unknown: s.i86 = i0
    def put(s, *bs):                      # bytes into the ROM's receive ring, as its serial interrupt does
        c = s.c; wp = c.m[0x9d8]
        for b in bs: c.m[0x8d6 + wp] = b & 0xff; wp = (wp + 1) & 0xff
        c.m[0x9d8] = wp
    def pending(s): return (s.c.m[0x9d8] - s.c.m[0x8016]) & 0xff
    def passes_run(s, n, limit=60_000_000):
        t = s.passes + n + (1 if s.c.ip == s.lp else 0); k = 0
        while s.passes < t:
            s.step(); k += 1
            if k > limit: raise RuntimeError('limit')
    def to_loop(s): s.run_until(lambda: s.c.ip == s.lp)
    def table(s, title=''):
        p = s.acc['pass']; out = [title + '  passes %d, clocks per pass: %.0f data-sheet, %.0f bus-limited estimate (x%.2f)' % (p[0], p[1] / max(1, p[0]), p[2] / max(1, p[0]), p[2] / max(1, p[1]))]
        for st in STAGES:
            t = s.acc[st]
            if t[0]: out.append('  %-9s calls %5d  clocks per call %8.0f  bus-limited %8.0f (x%.2f)' % (st, t[0], t[1] / t[0], t[2] / t[0], t[2] / max(1, t[1])))
        return '\n'.join(out)

    # ---- a MIDI byte stream arriving in time: byte k lands in the ring when the clock count passes T[k]
    def stream(s, events):
        """events: list of (clock, [bytes], tag). Bytes of one message land 2560 clocks apart (320 us at 8 MHz x share)."""
        s.ev = sorted(events, key=lambda e: e[0]); s.evi = 0; s.sent = []; s.t0 = s.v30
        def hook(h):
            while h.evi < len(h.ev) and h.v30 - h.t0 >= h.ev[h.evi][0]:
                t, bs, tag = h.ev[h.evi]; h.evi += 1
                # the ROM's interrupt writes whatever arrives; FZED's reader (CS:8016h) is not checked
                before = h.pending(); h.put(*bs); h.sent.append((t, tag, before + len(bs) > 255))
        s.hooks.append(hook)
    def watch_dispatch(s):
        s.got = []; a = s.stage['DISPATCH']
        def hook(h):
            if h.c.ip == a: h.got.append((h.v30 - h.t0, h.c.m[0x8019], h.c.r['ax'] & 0xff))
        s.hooks.append(hook)
    def live(s, cc112, wet=127, extra=None):
        for n, v in (extra or {}).items(): s.cc(n, v, 30000)
        s.cc(112, cc112, 60000); s.cc(117, wet, 60000); s.cc(119, 127, 30000)
        s.run_until(lambda: s.c.m[s.MAP['LVON']] == 2 and s.c.m[s.MAP['LVDIRTY']] == 0 and s.M16(s.MAP['CBK']) == 0xffff, 8_000_000)
def cen15(b):                              # centre CC112 value of FX band b (0-14)
    lo = -(-b * 128 // 15); hi = -(-(b + 1) * 128 // 15) - 1; return (lo + hi) // 2
