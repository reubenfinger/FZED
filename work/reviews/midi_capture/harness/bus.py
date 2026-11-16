# Bus-limited timing estimate for the V50 (an estimate, not a cycle-exact model).
# The data-sheet clock counts in cyc.py assume the instruction's bytes are already in the prefetch queue. On the real
# chip every code byte has to be fetched over the same bus the data uses: one bus cycle (4 clocks, plus wait states)
# brings one word. This model keeps a 6-byte queue (V30/V50), lets the bus unit fetch whenever the bus is idle and the
# queue has room, makes the execution unit wait for bytes it does not have yet, makes data cycles wait for a fetch in
# progress, and empties the queue on every taken jump, call, return and loop.
import re
CAP = 6
def data_cycles(txt, n):
    """bus cycles for data in one instruction (reads + writes; a rep string instruction: per element)"""
    t = txt.split(';')[0].strip()
    t = re.sub(r'^\.?[A-Za-z_][A-Za-z0-9_.]*:\s*', '', t)
    m = re.match(r'(rep[a-z]*\s+)?([a-z0-9]+)\s*(.*)$', t)
    if not m: return 0
    rep, op, rest = m.group(1), m.group(2), m.group(3)
    ops = [x.strip() for x in rest.split(',')] if rest else []
    mem = any('[' in o for o in ops); dst_mem = bool(ops) and '[' in ops[0]
    if op in ('movsw', 'movsb'): return 2 * (n if rep else 1)
    if op in ('stosw', 'stosb', 'lodsw', 'lodsb'): return (n if rep else 1)
    if op in ('push', 'pop'): return 2 if mem else 1
    if op == 'pusha' or op == 'popa': return 8
    if op == 'call': return 2 if mem else 1
    if op == 'ret': return 1
    if op == 'int3': return 5
    if op == 'iret': return 3
    if op in ('in', 'out'): return 1
    if op in ('xlatb', 'xlat'): return 1
    if not mem: return 0
    if op in ('mov', 'lea'): return 0 if op == 'lea' else 1
    if op in ('cmp', 'test', 'mul', 'imul', 'div', 'idiv'): return 1
    if op == 'jmp': return 1
    if op in ('add', 'sub', 'and', 'or', 'xor', 'adc', 'sbb', 'inc', 'dec', 'neg', 'not', 'xchg', 'shl', 'shr', 'sar', 'sal', 'rol', 'ror', 'rcl', 'rcr'):
        return 2 if dst_mem else 1
    return 1
FLOW = ('jmp', 'call', 'ret', 'loop', 'jcxz', 'int3', 'iret')
class Bus:
    def __init__(s, wcode=0, wdata=0, wwave=1, wio=1):
        s.t = 0.0; s.q = 0; s.busy = 0.0; s.infl = None; s.room = 0.0
        s.wcode, s.wdata, s.wwave, s.wio = wcode, wdata, wwave, wio
        s.fetches = 0; s.datac = 0; s.stall = 0.0
    def _fetch(s, until):
        while True:
            if s.infl is not None:
                if s.infl <= until: s.q = min(CAP, s.q + 2); s.infl = None
                else: return
            if s.q <= CAP - 2:
                st = max(s.busy, s.room)
                if st < until:
                    s.busy = st + 4 + s.wcode; s.infl = s.busy; s.fetches += 1
                else: return
            else: return
    def ins(s, length, clocks, dcyc, taken_flow, wave=False, io=False):
        need = min(length, CAP)
        s._fetch(s.t)
        t0 = s.t
        while s.q < need:                       # wait for the bytes
            if s.infl is None:
                st = max(s.busy, s.t); s.busy = st + 4 + s.wcode; s.infl = s.busy; s.fetches += 1
            s.t = max(s.t, s.infl); s.q = min(CAP, s.q + 2); s.infl = None
        s.stall += s.t - t0
        s.q -= need; s.room = s.t
        eu = clocks - 4 * dcyc - (4 if taken_flow else 0)
        if eu < 1: eu = 1
        s.t += eu
        w = s.wio if io else (s.wwave if wave else s.wdata)
        for _ in range(dcyc):
            s._fetch(s.t)
            st = max(s.t, s.busy); s.busy = st + 4 + w; s.t = s.busy; s.datac += 1
        if taken_flow:
            s._fetch(s.t); s.q = 0; s.infl = None; s.room = s.t     # a fetch in progress is thrown away; the bus stays busy until it ends
        return s.t
def flow(txt):
    t = re.sub(r'^\.?[A-Za-z_][A-Za-z0-9_.]*:\s*', '', txt.split(';')[0].strip())
    op = t.split()[0] if t.split() else ''
    return op in FLOW or op.startswith('j')
