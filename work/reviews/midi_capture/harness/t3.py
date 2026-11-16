import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# data-sheet clocks against the bus-limited estimate for one pass of the main loop: idle, and each live mode given
import mh
bd = sys.argv[1]
for band in [int(x) for x in sys.argv[2].split(',')]:
    wet = int(sys.argv[3]) if len(sys.argv) > 3 else 127
    h = mh.M(bd)
    if band >= 0: h.live(mh.cen15(band), wet)
    h.to_loop(); h.passes_run(10); h.reset_counts(); h.passes_run(40)
    b = h.bus
    print(h.table('band %d (mode %d) wet %d' % (band, h.c.m[h.MAP['FXM']], wet)))
