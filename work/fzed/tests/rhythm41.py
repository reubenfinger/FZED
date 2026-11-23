# FZED41S capture RHYTHM (FZED 27): ARP UP / DOWN / RANDOM and STRIKE on the pattern's steps while a capture holds.
#   VER=fzed python3 rhythm41.py
import os
os.environ['FZTIMER'] = '1'
V = os.environ.get('VER', 'fzed')
exec(open('romfix.py').read())
src = romfix(open('cap_t.py').read()).replace('perf38t', V)
exec(src.split("cc(102, 64); cc(103, 5 * 8)")[0])
B = MAP['CRLM'] - 0x7C4
ok = True
def check(k, msg):
    global ok
    print(('PASS ' if k else 'FAIL ') + msg); ok = ok and k
def fz(k, v): cc(10, 88, 20000); cc(11, k, 20000); cc(10, 89, 20000); cc(11, v, 40000)
notes = []
prev3 = c.int3
def i3():
    sp = c.r['sp']; fn = c.rd16(sp)
    if fn == 0x33:
        a = [c.rd16(sp + 2 * i) for i in range(1, 4)]
        if a[0] in (0x80, 0x90): notes.append((a[0], a[1]))
    prev3()
c.int3 = i3
cc(105, 127); cc(102, 64); cc(103, 5 * 8)                 # hold until RECAPTURE, 100 ms at 9 kHz
c.m[0xD0DD] = 8; c.m[0xD0DC] = 1                          # pattern: free, fast steps; EIGHTHS
cc(108, 127, 3_000_000)
for _ in range(400):
    if c.m[B + 0x7e0] == 2: break
    run(c, u, 20000)
cc(96, 50)                                                # intervals (CAPTURE 2 while capturing): MAJOR, 3 notes
cc(109, 127, 20000); cc(109, 0, 20000)                    # RECAPTURE: the next take plays the chord
for _ in range(600):
    run(c, u, 20000)
    if c.m[B + 0x7e0] == 2 and c.m[B + 0x7ca] == 3: break
n = c.m[B + 0x7ca]; keys = [c.m[B + 0x7ce + i] for i in range(n)]
check(c.m[MAP['CAPON']] == 1 and c.m[B + 0x7e0] == 2 and n == 3, 'capture holding a 3-note chord %s (CST %d)' % (keys, c.m[B + 0x7e0]))
run(c, u, 400000)
def steps(mode, t=3_000_000):
    fz(27, mode); notes.clear(); run(c, u, t); return list(notes)
s = steps(0)
check(s == [], 'RHYTHM OFF: the chord just holds (%d note events)' % len(s))
s = steps(30)
ons = [k for st, k in s if st == 0x90]
up = sum(1 for i in range(1, len(ons)) if keys.index(ons[i]) == (keys.index(ons[i - 1]) + 1) % n)
check(len(ons) >= 6 and up >= len(ons) - 2, 'ARP UP: one note at a time, up the chord (%d of %d steps): %s' % (up, len(ons) - 1, ons[:9]))
check(all(any(st == 0x80 and k == kk for st, k in s[:3 * n + 1]) for kk in keys), 'ARP UP: the held chord stopped first')
s = steps(60)
ons = [k for st, k in s if st == 0x90]
dn = sum(1 for i in range(1, len(ons)) if keys.index(ons[i]) == (keys.index(ons[i - 1]) - 1) % n)
check(len(ons) >= 6 and dn >= len(ons) - 2, 'ARP DOWN: down the chord (%d of %d steps; the count wraps every 256): %s' % (dn, len(ons) - 1, ons[:9]))
s = steps(90)
ons = [k for st, k in s if st == 0x90]
check(len(ons) >= 6 and set(ons) <= set(keys), 'ARP RANDOM: chord notes in some order: %s' % ons[:9])
s = steps(120)
ons = [k for st, k in s if st == 0x90]
check(len(ons) >= 2 * n and len(ons) % n == 0 and all(sorted(ons[i:i + n]) == sorted(keys) for i in range(0, len(ons), n)), 'STRIKE: the whole chord again on the pattern steps (%d strikes)' % (len(ons) // n))
fz(27, 0); cc(109, 127, 20000); cc(109, 0, 400000)
check(c.m[MAP['CAPON']] == 1, 'RECAPTURE still works with the rhythm set')
print('ALL PASS' if ok else 'SOME FAIL')
