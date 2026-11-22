# FZED41K STATUS OUT (FZED 24): record state, rate and slice count to MIDI OUT as CC3 on channel 16, each on a change.
#   python3 status41.py BUILD   (a folder holding fzedflat.bin and fzed.map)
import os, sys
T = os.path.dirname(os.path.abspath(__file__))
sys.argv = [sys.argv[0], sys.argv[1]]
exec(open(os.path.join(T, 'ext41.py')).read().split('ok = True')[0])
ok = True
def check(c_, msg):
    global ok
    print(('PASS ' if c_ else 'FAIL ') + msg); ok = ok and c_
g = boot(); c = g['c']
sent = lambda: [tuple(a[:3]) for f, a in c.api if f == 0x33]
c.api.clear(); g['run'](c, g['u'], 1000000)
check(sent() == [], 'off at start-up: nothing sent (%s)' % sent())
c.api.clear(); fzed(g, 24, 127); g['run'](c, g['u'], 400000)
s = sent(); rst = c.m[0x8010]; rate = c.m[0x4d9] & 3; nb = c.m[0x8244]
check(s == [(0xbf, 3, rst), (0xbf, 3, 16 + rate), (0xbf, 3, 64 + nb)], 'on: state %d, rate %d, slices %d sent once each as CC3 channel 16: %s' % (rst, rate, nb, s))
c.api.clear(); g['run'](c, g['u'], 1000000)
check(sent() == [], 'no change: nothing more (%s)' % sent())
uart = lambda: [x[2] for x in c.log if x[0] == 'out' and x[1] == 0xd0]
c.ports[0xd2] = 1                           # the 8251 ready to send (TxRDY)
c.api.clear(); c.log.clear(); c.m[0x8010] = 1; g['run'](c, g['u'], 3000000); c.m[0x8010] = 2; g['run'](c, g['u'], 3000000)
check(sent() == [] and uart() == [0xbf, 3, 1, 0xbf, 3, 2], 'ARMED then WAIT (the ROM\'s MIDI interrupts off): straight to the UART, one message each (%s; ROM %s)' % (uart(), sent()))
c.log.clear(); c.m[0x8010] = 3; c.m[0x4d7] = 3; g['run'](c, g['u'], 3000000)
check(uart() == [0xbf, 3, 3], 'RECORDING: straight to the UART (%s)' % uart())
c.api.clear(); c.log.clear(); c.m[0x8010] = 0; g['run'](c, g['u'], 3000000)
check(sent() == [(0xbf, 3, 0)] and uart() == [], 'back to IDLE: through the ROM again (%s; UART %s)' % (sent(), uart()))
c.api.clear(); c.m[0x8244] = 9; g['run'](c, g['u'], 300000)
check(sent() == [(0xbf, 3, 73)], 'slices 9: 64 + 9 (%s)' % sent())
c.api.clear(); fzed(g, 24, 0); c.m[0x8010] = 4; g['run'](c, g['u'], 600000)
check(sent() == [], 'off: a change sends nothing (%s)' % sent())
c.api.clear(); fzed(g, 24, 100); g['run'](c, g['u'], 300000)
check(sent() == [(0xbf, 3, 4), (0xbf, 3, 16 + rate), (0xbf, 3, 73)], 'on again: everything sent again (%s)' % sent())
print('ALL PASS' if ok else 'SOME FAIL')
