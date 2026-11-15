import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# The same MIDI byte stream into two builds: the CCs applied (number, value, in order), FZED's RAM and the LCD lines
# at the end must match.  usage: eqmidi.py OLD NEW
import mh, random
def run(bd, live):
    h = mh.M(bd, timing=False)
    if live: h.live(mh.cen15(0))
    h.to_loop(); h.got = []; a = h.stage['DISPATCH']
    h.hooks.append(lambda x: x.got.append((x.c.m[0x8019], x.c.r['ax'] & 0xff)) if x.c.ip == a else None)
    r = random.Random(7); st = None
    def msg():
        k = r.randrange(10)
        if k < 5: return [0xb0 | r.choice((0, 0, 3)), r.choice((74, 75, 71, 73, 78, 117, 113, 10, 11, 1, 5, 89, 90)), r.randrange(128)]
        if k == 5: return [0x90, 60 + r.randrange(12), r.choice((0, 100))]
        if k == 6: return [0xe0, 0, r.randrange(128)]
        if k == 7: return [0xf8]
        if k == 8: return [0xd0, r.randrange(128)]
        return [0xf0, 0x44, 1, 2, 0xf7]
    for burst in range(60):
        bs = []
        for _ in range(r.randrange(1, 12)):
            m = msg()
            if m[0] < 0xf0 and m[0] == st and r.random() < .6: m = m[1:]      # running status
            elif m[0] < 0xf0: st = m[0]
            elif m[0] != 0xf8: st = None
            if len(m) > 1 and r.random() < .3: m = m[:1] + [0xf8] + m[1:]     # realtime byte inside a message
            bs += m
        h.put(*bs[:int(os.environ.get("BURST", "200"))]); h.passes_run(r.randrange(1, 30))
    h.passes_run(400)
    skip = set(range(0x4000, 0x6000)) | {h.MAP.get('CCN', 0xD2DB)}
    ram = bytes(b for i, b in enumerate(h.c.m[0x8000:0xD400]) if (i + 0x8000) not in skip)
    return h.got, ram, [x[2] for x in h.c.log if x[0] == 'lcd'][-6:], h.M16(h.MAP['PCNT'])
for live in (0, 1):
    a = run(sys.argv[1], live); b = run(sys.argv[2], live)
    print('live %d: CCs applied %d / %d, same order and values: %s; RAM 8000h-D3FFh same: %s; last LCD lines same: %s; clock count same: %s'
          % (live, len(a[0]), len(b[0]), a[0] == b[0], a[1] == b[1], a[2] == b[2], a[3] == b[3]))
    if a[1] != b[1]: print('   differing offsets', [hex(0x8000 + i) for i in range(len(a[1])) if a[1][i] != b[1][i]][:12])
