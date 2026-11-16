# Cycle model for the FZED emulator runs: listing text -> (V30/V50 clocks, 8086 clocks).
# V30 figures: NEC uPD70116 data sheet values (word operands; ranges taken at their midpoint).
# 8086 figures: Intel 8086 tables with EA times; immediate-count shifts (186 opcodes) are costed
# as the CL form (8+4n).  Sample-RAM wait states are counted separately (waits).
import re
R16 = {'ax', 'cx', 'dx', 'bx', 'sp', 'bp', 'si', 'di'}
R8 = {'al', 'cl', 'dl', 'bl', 'ah', 'ch', 'dh', 'bh'}
SR = {'es', 'cs', 'ss', 'ds'}
ALU = {'add', 'sub', 'and', 'or', 'xor', 'adc', 'sbb'}
SH = {'shl', 'shr', 'sar', 'sal', 'rol', 'ror', 'rcl', 'rcr'}
JCC = {'jz', 'jnz', 'je', 'jne', 'jc', 'jnc', 'jb', 'jae', 'jbe', 'ja', 'jl', 'jge', 'jle', 'jg', 'js', 'jns', 'jo', 'jno', 'jnb', 'jna', 'jp', 'jnp'}

def kind(o):
    o = o.strip()
    if '[' in o: return 'm'
    w = o.split()[-1]
    if w in R16: return 'r'
    if w in R8: return 'r8'
    if w in SR: return 's'
    return 'i'

def ea86(o):
    inner = o[o.index('[') + 1:o.index(']')]
    inner = re.sub(r'\b(es|cs|ds|ss):', '', inner)
    parts = [p.strip() for p in re.split(r'[+-]', inner) if p.strip()]
    regs = [p for p in parts if p in ('bx', 'bp', 'si', 'di')]
    disp = any(p not in ('bx', 'bp', 'si', 'di') for p in parts)
    if not regs: return 6
    if len(regs) == 1: return 9 if disp else 5
    base = 7 if set(regs) in ({'bx', 'si'}, {'bp', 'di'}) else 8
    return base + (4 if disp else 0)

class Unknown(Exception): pass

def cost(text, taken=False, n=0, cl=0):
    """text: instruction source text.  taken: branch taken.  n: rep count.  cl: CL at the time.
    returns (v30, i86, mem_accesses_through_an_es_override)"""
    t = text.split(';')[0].strip()
    t = re.sub(r'^\.?[A-Za-z_][A-Za-z0-9_.]*:\s*', '', t)
    seg = 2 if re.search(r'\b(es|cs|ss|ds):', t) else 0
    esacc = 1 if 'es:' in t else 0
    m = re.match(r'(rep[a-z]*\s+)?([a-z0-9]+)\s*(.*)$', t)
    if not m: raise Unknown(text)
    rep, op, rest = m.group(1), m.group(2), m.group(3)
    ops = [x.strip() for x in rest.split(',')] if rest else []
    k = [kind(o) for o in ops]
    byte = any(x == 'r8' for x in k) or 'byte' in rest
    k = ['r' if x == 'r8' else x for x in k]
    ea = ea86(next(o for o in ops if '[' in o)) if 'm' in k else 0
    def R(v, i, acc=None): return (v + seg, i + seg, esacc if acc is None else acc)
    if op == 'mov':
        a, b = k
        if a == 'r' and b == 'r': return R(2, 2)
        if 's' in (a, b) and 'm' not in (a, b): return R(2, 2)
        if a == 'r' and b == 'i': return R(4, 4)
        if a == 'r' and b == 'm':
            if ops[0] in ('ax', 'al') and ea == 6: return R(10, 10)
            return R(11, 8 + ea)
        if a == 'm' and b == 'r':
            if ops[1] in ('ax', 'al') and ea == 6: return R(9, 10)
            return R(9, 9 + ea)
        if a == 'm' and b == 'i': return R(11, 10 + ea)
        if a == 's' and b == 'm': return R(11, 8 + ea)
        if a == 'm' and b == 's': return R(10, 9 + ea)
    if op in ALU:
        a, b = k
        if a == 'r' and b == 'r': return R(2, 3)
        if a == 'r' and b == 'i': return R(4, 4)
        if a == 'r' and b == 'm': return R(11, 9 + ea)
        if a == 'm' and b == 'r': return R(16, 16 + ea, 2 * esacc)
        if a == 'm' and b == 'i': return R(18, 17 + ea, 2 * esacc)
    if op == 'cmp':
        a, b = k
        if a == 'r' and b == 'r': return R(2, 3)
        if a == 'r' and b == 'i': return R(4, 4)
        if 'm' in (a, b) and 'i' not in (a, b): return R(11, 9 + ea)
        if a == 'm' and b == 'i': return R(13, 10 + ea)
    if op == 'test':
        a, b = k
        if a == 'r' and b == 'r': return R(2, 3)
        if a == 'r' and b == 'i': return R(4, 5)
        if 'm' in (a, b) and 'i' not in (a, b): return R(10, 9 + ea)
        if a == 'm' and b == 'i': return R(11, 11 + ea)
    if op in ('inc', 'dec'):
        if k[0] == 'r': return R(2, 3 if byte else 2)
        return R(16, 15 + ea, 2 * esacc)
    if op in ('neg', 'not'):
        if k[0] == 'r': return R(2, 3)
        return R(16, 16 + ea, 2 * esacc)
    if op == 'mul':
        if k[0] == 'r': return R(22, 74) if byte else R(30, 126)
        return R(28, 80 + ea) if byte else R(36, 132 + ea)
    if op == 'imul':
        if k[0] == 'r': return R(36, 89) if byte else R(44, 141)
        return R(42, 95 + ea) if byte else R(50, 147 + ea)
    if op == 'div':
        if k[0] == 'r': return R(19, 85) if byte else R(25, 153)
        return R(25, 91 + ea) if byte else R(31, 159 + ea)
    if op == 'idiv':
        if k[0] == 'r': return R(32, 107) if byte else R(41, 175)
        return R(38, 113 + ea) if byte else R(47, 181 + ea)
    if op in SH:
        cnt = ops[1]
        if cnt == '1':
            return R(2, 2) if k[0] == 'r' else R(16, 15 + ea, 2 * esacc)
        nn = (cl & 0xff) if cnt == 'cl' else int(cnt, 0)
        return R(7 + nn, 8 + 4 * nn) if k[0] == 'r' else R(19 + nn, 20 + ea + 4 * nn, 2 * esacc)
    if op == 'push':
        if k[0] == 'r': return R(8, 11)
        if k[0] == 's': return R(8, 10)
        if k[0] == 'm': return R(18, 16 + ea)
        return R(8, 10)
    if op == 'pop':
        if k[0] in ('r', 's'): return R(8, 8)
        return R(17, 17 + ea)
    if op == 'pusha': return R(35, 36)
    if op == 'popa': return R(43, 51)
    if op == 'call':
        if k[0] == 'i': return R(16, 19)
        if k[0] == 'r': return R(14, 16)
        return R(23, 21 + ea)
    if op == 'ret': return R(20, 20) if ops else R(15, 16)
    if op == 'jmp':
        if k[0] == 'i': return R(12, 15)
        if k[0] == 'r': return R(11, 11)
        return R(20, 18 + ea)
    if op in JCC: return R(14, 16) if taken else R(4, 4)
    if op == 'loop': return R(13, 17) if taken else R(5, 5)
    if op == 'jcxz': return R(13, 18) if taken else R(5, 6)
    if op == 'xchg':
        if 'm' in k: return R(16, 17 + ea, 2 * esacc)
        return R(3, 3 if 'ax' in ops else 4)
    if op == 'lea': return R(4, 2 + ea, 0)
    if op == 'cbw': return R(2, 2)
    if op == 'cwd': return R(4, 5)
    if op in ('clc', 'stc', 'cld', 'std', 'cli', 'sti', 'cmc'): return R(2, 2)
    if op == 'nop': return R(3, 3)
    if op == 'in': return R(9, 10)
    if op == 'out': return R(8, 10)
    if op == 'xlatb' or op == 'xlat': return R(9, 11)
    if op in ('lodsw', 'lodsb'): return R(7, 12)
    if op in ('stosw', 'stosb'):
        if rep: return R(7 + 4 * n, 9 + 10 * n)
        return R(7, 11)
    if op in ('movsw', 'movsb'):
        if rep: return R(11 + 8 * n, 9 + 17 * n, n)      # n word transfers, one side in the sample window
        return R(11, 18)
    if op == 'int3': return R(50, 52)
    if op == 'iret': return R(39, 24)
    if op == 'sahf' or op == 'lahf': return R(3, 4)
    if op == 'aam': return R(15, 83)
    if op == 'aad': return R(7, 60)
    raise Unknown(text)

def load_listing(path):
    """address -> (source text, byte length)"""
    base = 0x6000; out = {}; lines = []; pend = None
    for l in open(path, errors='replace'):
        m = re.match(r'^\s*\d+\s+([0-9A-F]{8})\s+([0-9A-F\[\]\(\)]+)(-?)\s+(?:<\d+>\s)?(.*)$', l)
        s = re.match(r'^\s*\d+\s+(?:<\d+>\s+)?section\s+(\S+).*vstart=0x([0-9A-Fa-f]+)', l)
        if s: base = int(s.group(2), 16); continue
        if not m:
            lines.append((None, l.rstrip('\n'))); continue
        off = int(m.group(1), 16); hexb = re.sub(r'[\[\]\(\)]', '', m.group(2)); txt = m.group(4)
        a = base + off
        if pend is not None and not txt.strip():
            if pend in out: out[pend] = (out[pend][0], out[pend][1] + len(hexb) // 2)
            if not m.group(3): pend = None
            continue
        pend = a if m.group(3) else None
        if txt.strip() and not re.match(r'\s*(db|dw|dd|times|resb|resw)\b', re.sub(r'^\s*\.?[A-Za-z_][A-Za-z0-9_.]*:\s*', '', txt.split(';')[0])):
            if a not in out:
                out[a] = (txt, len(hexb) // 2)
                mn = re.sub(r'^\s*\.?[A-Za-z_][A-Za-z0-9_.]*:\s*', '', txt.split(';')[0]).split()
                if mn and mn[0] in JCC and len(hexb) == 10:      # NASM's long form: inverse jcc over a near jmp
                    out[a] = (txt, 2); out[a + 2] = ('jmp ' + mn[-1], 3)
        lines.append((a, txt))
    return out, lines
