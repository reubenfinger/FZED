import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# cost of each MIDI message type: clocks in PARSE / MROUTE / DISPATCH / ECHOF in the pass that takes it, and FZ calls made
import mh, json
h = mh.M(sys.argv[1]); h.to_loop(); h.passes_run(50)
MSG = [('note on', [0x90, 60, 100]), ('note off', [0x80, 60, 0]), ('note on, running status x3', [0x90, 60, 100, 62, 100, 64, 100]),
       ('note off x3 (vel 0, running)', [0x90, 60, 0, 62, 0, 64, 0]),
       ('pitch bend', [0xe0, 0, 80]), ('channel pressure', [0xd0, 90]), ('poly pressure', [0xa0, 60, 90]), ('program change', [0xc0, 5]),
       ('clock F8', [0xf8]), ('start FA', [0xfa]), ('stop FC', [0xfc]), ('active sensing FE', [0xfe]),
       ('SysEx, 10 bytes', [0xf0, 0x44, 0, 0, 0x70, 1, 2, 3, 4, 0xf7]),
       ('CC1 mod wheel', [0xb0, 1, 64]), ('CC5 glide time', [0xb0, 5, 64]), ('CC7 (unused, below 10)', [0xb0, 7, 64]),
       ('CC74 cutoff', [0xb0, 74, 64]), ('CC75 resonance', [0xb0, 75, 64]), ('CC71 tape speed', [0xb0, 71, 70]), ('CC73 LFO rate', [0xb0, 73, 64]),
       ('CC78 DCA attack', [0xb0, 78, 64]), ('CC76 sample start', [0xb0, 76, 20]), ('CC77 sample end', [0xb0, 77, 100]),
       ('CC87 loop start', [0xb0, 87, 30]), ('CC72 crossfade', [0xb0, 72, 30]), ('CC70 play mode', [0xb0, 70, 40]),
       ('CC89 LFO2 rate', [0xb0, 89, 64]), ('CC90 LFO2 depth', [0xb0, 90, 64]), ('CC10 select', [0xb0, 10, 100]), ('CC11 value (matrix amount)', [0xb0, 11, 64]),
       ('CC117 FX mix', [0xb0, 117, 100]), ('CC113 FX p1', [0xb0, 113, 64]), ('CC115 FX p3', [0xb0, 115, 64]), ('CC112 FX type', [0xb0, 112, 4]),
       ('CC96 chop', [0xb0, 96, 10]), ('CC102 rec rate', [0xb0, 102, 64]), ('CC103 rec length', [0xb0, 103, 30]),
       ('CC120 all sound off', [0xb0, 120, 0]), ('CC123 all notes off', [0xb0, 123, 0])]
base = {}
out = {}
def one(name, bs, pre=None):
    h.to_loop(); h.passes_run(30); h.to_loop()
    h.reset_counts(); p0 = h.passes
    lcd0 = len([x for x in h.c.log if x[0] == 'lcd'])
    if bs: h.put(*bs)
    h.passes_run(1)
    a = {k: h.acc[k][1] for k in mh.STAGES + ['pass']}
    left = h.pending(); rom = dict(h.rom)
    # follow-on: passes until the ring is empty and the LCD has caught up
    h.reset_counts(); h.passes_run(40)
    lcd1 = len([x for x in h.c.log if x[0] == 'lcd'])
    return dict(a, left=left, rom=rom, lcd=lcd1 - lcd0, after=h.acc['pass'][1] / 40)
b = one('nothing', [])
print('empty pass: PARSE %d  pass %d  (idle wait included); 40-pass average %d' % (b['PARSE'], b['pass'], b['after']))
print('%-30s %7s %7s %8s %7s %9s  %s' % ('message', 'PARSE', 'MROUTE', 'DISPATCH', 'ECHOF', 'pass', 'FZ calls / LCD lines / bytes left'))
for name, bs in MSG:
    r = one(name, bs); out[name] = r
    print('%-30s %7d %7d %8d %7d %9d  %s lcd %d left %d' % (name, r['PARSE'], r['MROUTE'], r['DISPATCH'], r['ECHOF'], r['pass'], {k: v for k, v in r['rom'].items() if k != 6}, r['lcd'], r['left']))
json.dump(out, open(sys.argv[2], 'w'), indent=1)
