# FZED41A: the one-time start-up moved to the start-up overlay (sector 51). Boot two builds with the same fixture and
# compare what start-up leaves behind: FZED's variables and data (8000h-83FFh, BE00h-D3FFh), the FZ's RAM (0000h-5FFFh),
# the ROM calls made (sector loads aside), the LCD lines and the first main-loop CCs. Also: the start-up sector loaded,
# the FZ-call stack stayed above its code, and an empty edit voice takes the EMPTY-REC READY path too.
# usage: python3 startup41.py OLD_FLAT OLD_MAP NEW_FLAT NEW_MAP
import sys, os
sys.path.insert(0, os.getcwd())
from emu import CPU
from uart import UART
V1 = 0x2288 + 0xc0; EV = 0x2288 + 0xc0 * 5; BANK = 0x0e08

def boot(flat, evmode, extra=None):
    full = open(flat, 'rb').read()
    c = CPU(full[:1024] + bytes(3072)); c.codeend = 0xB800; c.push(0xdead)
    c.wr16(0xe04, EV); c.wr16(0xe06, 0); c.wr16(0xe02, 5)
    c.wr16(EV + 0x10, evmode); c.wr16(EV + 12, 0x3e38); c.wr16(EV + 14, 2)
    for i in range(0x14, 0xb2): c.m[EV + i] = (i * 7) & 0x7f
    c.wr16(0xdfe, BANK); c.wr16(BANK, 1); c.wr16(BANK + 0x202, V1)
    c.wr16(0x9d8, 0x20)
    loads = []; minsp = [0x10000]
    oi = c.int3
    def i3():
        sp = c.r['sp']; fn = c.rd16(sp); a = [c.rd16(sp + 2 * i) for i in range(1, 5)]
        minsp[0] = min(minsp[0], sp) if sp < 0xdc00 else minsp[0]
        if fn == 0xbf:
            loads.append(a[0]); pcl, off = a[0], a[1]
            c.m[off:off + 1024] = (full[(pcl - 17) * 1024:] + bytes(1024))[:1024]; c.r['ax'] = 0; return
        if fn in (45, 46, 47, 48, 117, 119):
            c.r['ax'] = c.r['bx'] = 0; return
        if fn == 49: c.r['ax'] = c.r['bx'] = 1; return
        oi()
    c.int3 = i3
    u = UART(c, per=300)
    for _ in range(3_000_000):
        if c.exited: break
        u.tick(); c.step()
    return c, loads, minsp[0]

def midi(c, *bs):
    wp = c.rd16(0x9d8)
    for b in bs: c.m[0x8d6 + wp] = b; wp = (wp & 0xff00) | ((wp + 1) & 0xff)
    c.wr16(0x9d8, wp)

ok = True
def check(cond, msg):
    global ok
    print(('PASS ' if cond else 'FAIL ') + msg); ok &= bool(cond)

for evmode, name in ((0x1d7, 'voice in the edit buffer'), (0, 'empty edit voice')):
    o, ol, _ = boot(sys.argv[1], evmode)
    n, nl, nsp = boot(sys.argv[3], evmode)
    check(nl == ol[:26] + [51] + ol[26:],
          '%s: sectors loaded %s (old %s)' % (name, nl, ol))
    diffs = []
    for lo, hi in ((0x0000, 0x6000), (0x8000, 0x8400), (0xBE00, 0xD400)):
        for a in range(lo, hi):
            if o.m[a] != n.m[a] and a not in (0x55F6, 0x55F7): diffs.append(a)   # (L6004's saved return address)
    check(not diffs, '%s: RAM after start-up the same (%d bytes differ%s)' % (name, len(diffs), (': ' + ' '.join('%04X' % a for a in diffs[:12])) if diffs else ''))
    # call numbers and arguments, code addresses aside (return addresses and string pointers moved; the strings are
    # compared through the LCD lines)
    sig = lambda c: [(x[0], tuple(None if 0x6000 <= v < 0xF000 else v for v in x[1][:3])) for x in c.api if x[0] != 0xbf]
    check(sig(o) == sig(n), '%s: the same %d ROM calls in the same order' % (name, len(sig(n))))
    olcd = [x for x in o.log if x[0] == 'lcd']; nlcd = [x for x in n.log if x[0] == 'lcd']
    check(olcd == nlcd, '%s: the same LCD lines %r' % (name, [x[2] for x in nlcd][:4]))
    check(nsp == 0x10000 or nsp > 0xD7C0, '%s: FZ-call stack stayed above the start-up code (lowest %04X)' % (name, nsp if nsp < 0x10000 else 0))
    # the main loop works afterwards: a CC on both builds gives the same result
    uo = UART(o, per=300); un = UART(n, per=300)
    for c, u in ((o, uo), (n, un)):
        midi(c, 0xb0, 74, 0x34); midi(c, 0xb0, 70, 40)
        for _ in range(400_000): u.tick(); c.step()
    d2 = [a for lo, hi in ((0x8000, 0x8400), (0xBE00, 0xD400)) for a in range(lo, hi) if o.m[a] != n.m[a] and a not in (0x55F6, 0x55F7)]
    check(not d2 and [x for x in o.log if x[0] == 'lcd'] == [x for x in n.log if x[0] == 'lcd'],
          '%s: then CC74 and CC70: same RAM and LCD (%d bytes differ)' % (name, len(d2)))
print('ALL PASS' if ok else 'SOME FAILED')
