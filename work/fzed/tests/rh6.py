# RH6: FZED 34 RENDER FX renders the CC112 effect whatever EXT module is chosen, and leaves the module chosen; CC118
# still runs the module.
#   python3 rh6.py BUILD   (a folder holding fzedflat.bin and fzed.map)
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
lcd = lambda: [x[2].strip() for x in c.log if x[0] == 'lcd']
EXTS = MAP['EXTS']
fzed(g, 19, 40)
check(c.m[EXTS] == 5, 'module 5 chosen (EXTS %d)' % c.m[EXTS])
c.log.clear(); fzed(g, 34, 0); fzed(g, 34, 127); g['run'](c, g['u'], 6_000_000)
m = lcd()
check('EXT ADDITIVE' not in m and any('RENDER' in x for x in m) and c.m[EXTS] == 5, 'FZED 34: the effect renders, not the module, and module 5 stays chosen: %s (EXTS %d)' % (m[:6], c.m[EXTS]))
c.log.clear(); cc(g, 118, 0); g['midi'](c, 0xb0, 118, 127); g['run'](c, g['u'], 2_000_000)
check('EXT ADDITIVE' in lcd(), 'CC118 still runs the module: %s' % lcd()[:6])
print('ALL PASS' if ok else 'SOME FAIL')
