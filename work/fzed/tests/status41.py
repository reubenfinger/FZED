# FZED41K STATUS OUT (FZED 24): record state, rate and slice count to MIDI OUT as CC3 on channel 16, each on a change.
#   python3 status41.py BUILD   (a folder holding fzedflat.bin and fzed.map)
import os, sys
os.environ['FZTIMER'] = '1'
T = os.path.dirname(os.path.abspath(__file__))
sys.argv = [sys.argv[0], sys.argv[1]]
exec(open(os.path.join(T, 'ext41.py')).read().split('ok = True')[0])
ok = True
def check(c_, msg):
    global ok
    print(('PASS ' if c_ else 'FAIL ') + msg); ok = ok and c_
g = boot(); c = g['c']
c.ports[0xd2] = 1                           # the 8251 ready to send (TxRDY)
def msgs():                                 # RH4: everything goes straight to the UART (never the ROM's MIDI call)
    b = [x[2] for x in c.log if x[0] == 'out' and x[1] == 0xd0]
    out = []; i = 0
    while i + 2 < len(b):
        if b[i] == 0xbf: out.append(tuple(b[i:i + 3])); i += 3
        else: i += 1
    return out
rom = lambda: [a for f, a in c.api if f == 0x33]
sent = lambda: [m for m in msgs() if m[1] == 3]
text = lambda: ''.join(chr(m[2]) if m[2] else '|' for m in msgs() if m[1] == 9)
def clear(): c.api.clear(); c.log.clear()
clear(); g['run'](c, g['u'], 1000000)
check(msgs() == [], 'off at start-up: nothing sent (%s)' % msgs())
clear(); fzed(g, 24, 127); g['run'](c, g['u'], 3000000)
s = sent(); rst = c.m[0x8010]; rate = c.m[0x4d9] & 3; nb = c.m[0x8244]
check(s == [(0xbf, 3, rst), (0xbf, 3, 16 + rate), (0xbf, 3, 64 + nb)] and rom() == [], 'on: state %d, rate %d, slices %d sent once each as CC3 channel 16, straight to the UART, none through the ROM: %s' % (rst, rate, nb, s))
clear(); g['run'](c, g['u'], 1000000)
check(sent() == [], 'no change: nothing more (%s)' % sent())
clear(); c.m[0x8010] = 1; g['run'](c, g['u'], 3000000); c.m[0x8010] = 2; g['run'](c, g['u'], 3000000)
check(sent() == [(0xbf, 3, 1), (0xbf, 3, 2)], 'ARMED then WAIT: one message each (%s)' % sent())
clear(); c.m[0x8010] = 3; c.m[0x4d7] = 3; g['run'](c, g['u'], 3000000)
check(sent() == [(0xbf, 3, 3)], 'RECORDING (%s)' % sent())
clear(); c.m[0x8010] = 0; g['run'](c, g['u'], 3000000)
check(sent() == [(0xbf, 3, 0)] and rom() == [], 'back to IDLE: still straight to the UART (%s; ROM %s)' % (sent(), rom()))
clear(); c.m[0x8244] = 9; g['run'](c, g['u'], 3000000)
check(sent() == [(0xbf, 3, 73)], 'slices 9: 64 + 9 (%s)' % sent())
clear(); fzed(g, 24, 0); c.m[0x8010] = 4; g['run'](c, g['u'], 600000)
check(msgs() == [], 'off: a change sends nothing (%s)' % msgs())
clear(); fzed(g, 24, 100); g['run'](c, g['u'], 3000000)
check(sent() == [(0xbf, 3, 4), (0xbf, 3, 16 + rate), (0xbf, 3, 73)], 'on again: everything sent again (%s)' % sent())
c.m[0x8010] = 0; g['run'](c, g['u'], 3000000)
clear(); fzed(g, 19, 0); g['run'](c, g['u'], 12000000)
check(text().startswith('EXT 00|') and rom() == [], 'a message goes out as text, CC9 channel 16, none through the ROM: %r' % text())
clear()
for k, v in ((10, 88), (11, 19), (10, 89)): g['midi'](c, 0xb0, k, v); g['run'](c, g['u'], 5000)
for v in range(8, 40, 8): g['midi'](c, 0xb0, 11, v); g['run'](c, g['u'], 20000)
g['run'](c, g['u'], 12000000)
t = text(); check(1 <= t.count('|') <= 3, 'several in quick succession: at most one a quarter second, the latest kept: %r' % t)
g['run'](c, g['u'], 12000000); clear(); fzed(g, 24, 0); fzed(g, 19, 0); g['run'](c, g['u'], 3000000)
check(text() == '', 'STATUS OUT off: no text (%r)' % text())
print('ALL PASS' if ok else 'SOME FAIL')
