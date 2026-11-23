# FZED41Q BEND RANGE (FZED 25): the FZ's bend depth (5288h); with glide on, the depth glide gives back.
#   python3 bend41.py BUILD
import os, sys
T = os.path.dirname(os.path.abspath(__file__))
sys.argv = [sys.argv[0], sys.argv[1]]
exec(open(os.path.join(T, 'ext41.py')).read().split('ok = True')[0])
ok = True
def check(c_, msg):
    global ok
    print(('PASS ' if c_ else 'FAIL ') + msg); ok = ok and c_
g = boot(); c = g['c']
fzed(g, 25, 40); check(c.m[0x5288] == 40, 'BEND RANGE 40: bend depth 40 (%d)' % c.m[0x5288])
fzed(g, 25, 127); check(c.m[0x5288] == 127, 'BEND RANGE 127 (%d)' % c.m[0x5288])
c.m[0xC399] = 1; c.m[0xC398] = 20; c.m[0x5288] = 127      # glide on: depth open at 127, the player's kept
fzed(g, 25, 64); check(c.m[0x5288] == 127 and c.m[0xC398] == 64, 'glide on: the kept depth changes (%d), glide keeps 127 (%d)' % (c.m[0xC398], c.m[0x5288]))
c.m[0xC399] = 0
fzed(g, 24, 0); fzed(g, 19, 0); fzed(g, 25, 5); check(c.m[0x5288] == 5, 'BEND RANGE 5 (%d)' % c.m[0x5288])
print('ALL PASS' if ok else 'SOME FAIL')
