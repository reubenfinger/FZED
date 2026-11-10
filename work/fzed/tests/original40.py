# FZED: Loop Mode ORIGINAL puts the voice's own loop points back after the loop pots moved them
import os
V = os.environ.get('VER', 'perf40n')
exec(open('romfix.py').read())
src = romfix(open('cap_t.py').read()).replace('perf38t', V)
exec(src.split("cc(102, 64); cc(103, 5 * 8)")[0])
def m(*b): midi(c, *b); run(c, u, 250000)
def res(name, ok, info=''): print(('PASS ' if ok else 'FAIL ') + name, info)
d32 = lambda a: c.rd16(a) | ((c.rd16(a + 2) & 0x1f) << 16)
try:
    si = c.rd16(0xe04)
    loops = lambda: [(d32(si + 0x14 + 4 * i), d32(si + 0x34 + 4 * i)) for i in range(8)]
    m(0xb0, 86, 64)
    orig = loops(); flags = c.rd16(si + 0x12)
    print('original', [hex(a) + '-' + hex(b) for a, b in orig[:2]], hex(flags))
    m(0xb0, 86, 127); m(0xb0, 87, 30); m(0xb0, 88, 100)
    moved = loops()
    res('loop pots move the loop', moved != orig, str([hex(a) + '-' + hex(b) for a, b in moved[:2]]))
    m(0xb0, 86, 64)
    res('ORIGINAL: loop points back', loops() == orig, str([hex(a) + '-' + hex(b) for a, b in loops()[:2]]))
    res('ORIGINAL: sustain / end loop back', c.rd16(si + 0x12) == flags, hex(c.rd16(si + 0x12)))
    m(0xb0, 86, 21); m(0xb0, 87, 50); m(0xb0, 86, 64)
    res('ONE-SHOT, pots, then ORIGINAL: loop points back', loops() == orig and c.rd16(si + 0x12) == flags)
except Exception:
    import traceback; traceback.print_exc()
