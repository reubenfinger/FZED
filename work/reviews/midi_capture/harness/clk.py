import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# a clock byte behind N queued CCs: passes until FZED's clock count (PCNT) moves
import mh
for bd in sys.argv[1:3]:
    for n in (0, 20, 60):
        h = mh.M(bd, timing=False); h.to_loop(); h.passes_run(20); h.to_loop()
        p0 = h.M16(h.MAP['PCNT']); bs = []
        for i in range(n): bs += [0xb0, 74, i]
        h.put(*(bs + [0xf8])); k = 0
        while h.M16(h.MAP['PCNT']) == p0 and k < 200: h.passes_run(1); k += 1
        print('%s: clock behind %2d CCs counted after %d passes' % (os.path.basename(bd), n, k))
