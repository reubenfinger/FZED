import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# after start-up: the variables the space-saving init changes write must match; then ESC (key 15h) must still leave FZED
import mh
r = []
for bd in sys.argv[1:3]:
    h = mh.M(bd, timing=False); h.to_loop(); h.passes_run(5)
    v = bytes(h.c.m[0x81EC:0x81F3]) + bytes(h.c.m[0x8242:0x8244]) + bytes(h.c.m[0x8252:0x8254])
    h.c.keyq = [0x15]; h.run(400000); r.append((v, h.c.exited))
print('init bytes same:', r[0][0] == r[1][0], r[1][0].hex(), '| ESC exits: old', r[0][1], 'new', r[1][1])
