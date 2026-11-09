#!/usr/bin/env python3
"""FZED templates for the Novation ReMOTE SL (MkI): three linked templates (SOUND, MOD, SAMPLE).

Every SL control sends on MIDI channel 16 to FZED (Remote SL input mode), which forwards to the FZ:
  CC n          a PERF direct CC, with the FZED value (the real CC number and value)
  NRPN 0 / p    PERF parameter p (FZED sends CC10 = p, CC11 = value)
  NRPN 1 / k    PERF control k (FZED sends parameter 88 = k, 89 = value)
  NRPN 2 / f    FZED function f (page, envelope step, controller source, matrix route, exit, capture...)
  NRPN 3 / s    selected envelope step: 0 amp rate, 1 amp level, 2 filter rate, 3 filter level
  NRPN 4 / s    selected controller source: 0 LFO pitch, 1 amp, 2 filter, 3 res, 4 amp offset, 5 filter offset, 6 res offset
  NRPN 5 / s    selected matrix route: 0 source, 1 amount, 2 destination
  NRPN 6 / s    FX parameter slot s (1-4) of the current effect
  NRPN 7 / n    PERF CC n that would clash with NRPN / RPN (CC98, CC99, CC100, CC101)
NRPN values are 7-bit: the SL sends CC99, CC98, then CC6 = value (seen on a ReMOTE SL).

Template format: Novation ReMOTE SL MkI template SysEx (4112 bytes, 90 x 41-byte control records), as
documented by the sl-template-editor project (Docs/FORMAT.md). The non-control settings (keyboard zones,
pedals, pads) come from a base template that has been sent to a ReMOTE SL.

Usage: build_sl_templates.py BASE.syx profile.json OUTDIR
"""
import json, sys, pathlib

BASE, PROFILE, OUT = sys.argv[1], sys.argv[2], pathlib.Path(sys.argv[3])
SIZE, CBASE, CSIZE = 4112, 419, 41
CH = 15            # MIDI channel 16
PORTS = 0x01       # USB 1 only: the editor forwards to the FZ. (0x05 also sent the raw NRPN out of MIDI 1, where its CC99/CC98 reached FZED as chop slices = 4 and play slices)
P = json.load(open(PROFILE))['controls']

def desc(code, group=None, variant=None):
    for d in P:
        if d['code'] == code and (group is None or d['group'] == group) and (variant is None or d['variant'] == variant):
            return d
    raise SystemExit(f'no descriptor {code} {group}')

def runs(d):
    """Wire-value sets of the distinct settings, in order (from the editor's labels)."""
    out, last = [], None
    for raw, label in enumerate(d['values']):
        if label != last:
            out.append(set()); last = label
        out[-1].add(d['wireValues'][raw])
    return out

def stepper(sets):
    """Low, step for an SL STEP button that lands once on each setting: low + step * k is in setting k."""
    n, best = len(sets), None
    for step in range(1, 65):
        for low in range(0, 128):
            vals = [low + step * k for k in range(n)]
            if vals[-1] > 127 or any(v not in s for v, s in zip(vals, sets)): continue
            margin = min(min(abs(v - x) for x in range(128) if x not in s) if len(s) < 128 else 99 for v, s in zip(vals, sets))
            if best is None or margin > best[0]: best = (margin, low, step)
    if best is None: raise SystemExit(f'no step pattern for {n} settings')
    return best[1], best[2]

# ---- control kinds -------------------------------------------------------------------------------------
def cc(name, num, lo=0, hi=127, **kw):            return dict(name=name, type=1, msb=0, lsb=num, lo=lo, hi=hi, **kw)
def nrpn(name, msb, lsb, lo=0, hi=127, **kw):     return dict(name=name, type=2, msb=msb, lsb=lsb, lo=lo, hi=hi, **kw)
def knob(name, d, via):
    w = d['wireValues']; lo, hi = min(w), max(w)
    return via(name, lo, hi) | dict(code=d['code'], label=d['label'])
def kcc(name, code, group=None):   d = desc(code, group); return knob(name, d, lambda n, lo, hi: cc(n, code, lo, hi))
def kpar(name, code, group=None):  d = desc(code, group); return knob(name, d, lambda n, lo, hi: nrpn(n, 0, d['sequence'][0][1], lo, hi))
def kmux(name, code):              d = desc(code); return knob(name, d, lambda n, lo, hi: nrpn(n, 1, d['sequence'][1][1], lo, hi))
def step_of(base, d):
    low, step = stepper(runs(d)); n = len(runs(d))
    return base | dict(lo=low, hi=low + step * (n - 1), step=step, button='step', code=d['code'], label=d['label'], settings=n)
def bcc(name, code, group=None):   d = desc(code, group); return step_of(cc(name, code), d)
def bpar(name, code, group=None):  d = desc(code, group); return step_of(nrpn(name, 0, d['sequence'][0][1]), d)
def uniform(base, n, label, code=None):
    """STEP button over n equal settings (0-127 split n ways), for settings whose count changes with another
    control (SUSTAIN AT follows the segment count): it covers the most, and PERF maps each press to its setting."""
    low, step = stepper([set(range((k * 128 + n - 1) // n, ((k + 1) * 128 + n - 1) // n)) for k in range(n)])
    return base | dict(lo=low, hi=low + step * (n - 1), step=step, button='step', code=code, label=label, settings=n)
def bmux(name, code):              d = desc(code); return step_of(nrpn(name, 1, d['sequence'][1][1]), d)
def toggle(base, d):
    r = runs(d); on, off = sorted(r[1])[len(r[1]) // 2], sorted(r[0])[len(r[0]) // 2]
    return base | dict(lo=on, hi=off, button='toggle', display=3, code=d['code'], label=d['label'])
def mom(base, press=127, release=0, label=''):    return base | dict(lo=press, hi=release, button='momentary', label=label)
def press(base, value=127, label=''):             return base | dict(lo=value, hi=value, button='normal', label=label)
FN = lambda name, f, **kw: nrpn(name, 2, f, **kw)
BLANK = None

# ---- layout -------------------------------------------------------------------------------------------
# Rows in record order: encoders, pots, sliders, left upper buttons (above the encoders), left lower buttons
# (between encoders and pots), right upper buttons, right lower buttons. Touchpad and transport are shared.
TRANSPORT = [press(FN('PAGE <', 0), 0, 'Editor page back'), press(FN('PAGE >', 0), 127, 'Editor page forward'),
             mom(cc('REC STOP', 109), label='RECORD STOP'), mom(cc('REC STRT', 107), label='RECORD START'),
             mom(cc('REC ARM', 106), label='RECORD ARM'), press(cc('REC AUTO', 108), 127, 'RECORD AUTO')]
TOUCH = [kcc('CUTOFF', 74), kcc('RES', 75), kcc('LFO2 DPT', 90), kcc('FX MIX', 117)]

SOUND = dict(name='FZED 1 SOUND', rows=[
  [kcc('ORIG KEY', 68), kcc('LOW KEY', 67), kcc('HIGH KEY', 66),
   nrpn('FX P2', 6, 1) | dict(label='FX parameter 2 (current effect)'), nrpn('FX P3', 6, 2) | dict(label='FX parameter 3'),
   nrpn('FX P4', 6, 3) | dict(label='FX parameter 4'), nrpn('FX P5', 6, 4) | dict(label='FX parameter 5'), kcc('FX MIX', 117)],
  [kcc('CUTOFF', 74), kcc('RES', 75), kcc('LFO RATE', 73), kcc('LFO PTCH', 53),
   kcc('LFO AMP', 54), kcc('LFO FLT', 55), kcc('LFO RES', 56), kcc('LFO ATK', 51)],
  [kcc('DCA ATK', 78), kcc('DCA DCY', 79), kcc('DCA SUS', 80), kcc('DCA REL', 81),
   kcc('DCF ATK', 82), kcc('DCF DCY', 83), kcc('DCF SUS', 84), kcc('DCF REL', 85)],
  [bcc('TAPE SPD', 71), bcc('LFO WAVE', 50), mom(nrpn('VOX INIT', 0, 7), label='VOICE INIT'),
   bcc('FX TYPE', 112), toggle(cc('FX LIVE', 119), desc(119)), mom(nrpn('FX DEL', 7, 100), label='DELETE UNUSED'),
   mom(nrpn('FX NORM', 7, 101), label='NORMALISE'), mom(cc('RENDER', 118), label='RENDER')],
  [bcc('AMP SUS', 12), bcc('AMP END', 13), bcc('FLT SUS', 30), bcc('FLT END', 31), BLANK, BLANK, BLANK, BLANK],
  [mom(cc('NEW VOX', 16), label='NEW VOICE'), press(nrpn('VOX SEL', 1, 12), 127, 'VOICE SELECT'),
   mom(nrpn('COPY VOX', 0, 126), label='COPY VOICE'), bcc('BANK SEL', 14),
   mom(cc('BANK ADD', 15), 0, 64, 'BANK ADD (add this voice)'), mom(cc('BANK CLR', 15), 127, 64, 'BANK CLEAR (this channel)'),
   BLANK, BLANK],
  [BLANK] * 8])

MOD = dict(name='FZED 2 MOD', rows=[
  [nrpn('CT PTCH', 4, 0) | dict(label='Controller LFO pitch (selected source)'), nrpn('CT AMP', 4, 1) | dict(label='Controller LFO amp'),
   nrpn('CT FLT', 4, 2) | dict(label='Controller LFO filter'), nrpn('CT RES', 4, 3) | dict(label='Controller LFO res'),
   FN('MX ROUTE', 3, lo=0, hi=9) | dict(label='Matrix route 1-10'), nrpn('MX SRC', 5, 0) | dict(label='Matrix source (selected route)'),
   nrpn('MX AMT', 5, 1) | dict(label='Matrix amount'), nrpn('MX DEST', 5, 2) | dict(label='Matrix destination')],
  [kcc('LFO2 RT', 89), kcc('LFO2 SHP', 91), kpar('LFO2 DLY', 257), kpar('LFO2 FAD', 258),
   kcc('LFO2 DPT', 90), kpar('LFO2 DP2', 1025), kpar('LFO1 DLY', 256), kpar('GLIDE', 261)],
  [kpar('AMP KF', 314), kpar('AMP RSC', 315), kpar('FLT KF', 316), kpar('FLT RSC', 317),
   kpar('V>AMP LV', 318), kpar('V>AMP RT', 319), kpar('V>FLT LV', 320), kpar('V>FLT RT', 321)],
  [press(FN('SRC MW', 2), 0, 'Controllers: mod wheel'), press(FN('SRC FOOT', 2), 1, 'Controllers: foot'),
   press(FN('SRC AT', 2), 2, 'Controllers: aftertouch'), bpar('GLIDE MD', 262),
   bcc('LFO2 MOD', 93), bcc('LFO2 DST', 92), step_of(FN('LFO2 DS2', 6), desc(1024)), kpar('VEL>RES', 313) | dict(button='step', lo=0, hi=127, step=16, settings=8)],
  [nrpn('CT AOFS', 4, 4, lo=0, hi=127) | dict(button='step', step=16, settings=8, label='Controller amp offset (8 steps)'),
   nrpn('CT FOFS', 4, 5) | dict(button='step', step=16, settings=8, label='Controller filter offset (8 steps)'),
   nrpn('CT ROFS', 4, 6) | dict(button='step', step=16, settings=8, label='Controller res offset (8 steps)'),
   BLANK, BLANK, BLANK, BLANK, BLANK],
  [BLANK] * 8, [BLANK] * 8])

SAMPLE = dict(name='FZED 3 SAMPLE', rows=[
  [kcc('PRESETWV', 111), kmux('ST TIME', 1537), kmux('ST SKEW', 1544), kcc('CAP TRNS', 23, 'capture'),
   kpar('SLC MOVE', 379), kpar('SLC LOW', 380), kpar('SLC HIGH', 381), kmux('VOX PICK', 1547)],
  [kcc('REC LEN', 103, 'record'), kcc('TRIG LVL', 105, 'record'), kcc('NORM FLT', 110, 'record'),
   kpar('SLICE', 378) | dict(label='SLICE (spans the chop\'s slice count)'), kcc('CAP SYNC', 33, 'capture'),
   kcc('CHOP SNS', 96, 'chop'), kpar('PAT RATE', 265), kmux('ST ORDER', 1543)],
  [kcc('SMP STRT', 76), kcc('SMP END', 77), kcc('LOOP STR', 87), kcc('LOOP END', 88),
   kcc('LOOP XFD', 72), kpar('WIN POS', 260), kmux('GRAIN', 1538), kmux('ST XFADE', 1539)],
  [bcc('PLAY MD', 70), bcc('LOOP MD', 86, 'loop'), bpar('WIN SNAP', 259), mom(cc('LOAD WV', 9), 0, 127, 'Load the selected preset wave'),
   toggle(nrpn('ST ON', 1, 9), desc(1545)), bmux('ST SNAP', 1540), uniform(nrpn('ST SUS', 1, 5), 9, 'STRETCH SUSTAIN AT (none, hold segment 1-8: as many as there are segments)', 1541), bmux('ST NEXT', 1542)],
  [bmux('ST SEGS', 1536), bcc('REC RATE', 102, 'record'), bcc('REC GAIN', 104, 'record'),
   FN('CAPTURE', 8) | dict(lo=127, hi=0, button='toggle', display=3, label='CAPTURE ON / OFF'),
   press(FN('EXIT ESC', 4), 0, 'EXIT PERF: discard'), press(FN('EXIT SND', 4), 1, 'EXIT PERF: keep sound'),
   press(FN('EXIT VOX', 4), 2, 'EXIT PERF: keep all of edit voice'), press(FN('EXIT ALL', 4), 3, 'EXIT PERF: keep all')],
  [step_of(nrpn('CHOP MD', 7, 97), desc(97, 'chop')), step_of(nrpn('CHOP CNT', 7, 99), desc(99, 'chop')),
   press(nrpn('MAKE SLC', 7, 98), 127, 'CHOP: create slices'), press(nrpn('PLAY SLC', 7, 98), 64, 'CHOP: play slices'),
   press(nrpn('RET VOX', 7, 98), 0, 'CHOP: return to voice'), bpar('CHOKE', 377, 'chop'), bpar('PATTERN', 264, 'chop'), bpar('SMOOTH', 343, 'chop')],
  [bmux('CHOPINTO', 1550), press(nrpn('FREEZE', 1, 15), 127, 'FREEZE CHOP'), FN('CAP REL', 9) | dict(lo=0, hi=112, button='step', step=16, settings=8, label='Capture AMP+FLT RELEASE (8 steps)'), bpar('SLC OUT', 383),
   bmux('SLC FEL', 1546), bcc('CAP HOLD', 105, 'capture'), bcc('CAP FADE', 34), bcc('CAP RLS', 41)]])

TEMPLATES = [SOUND, MOD, SAMPLE]

# ---- encoding -----------------------------------------------------------------------------------------
def record(base, c):
    r = bytearray(base)
    if c is None:
        r[0:8] = b' ' * 8; r[8] = 0; r[9:13] = bytes([0, 0, 0, 127]); r[13] = 0; r[15] = 0; r[16] = 0; r[17] = 0
        r[20:22] = b'\0\0'; r[22] = 0; r[26:41] = bytes(15); return bytes(r)
    name = c['name'][:8].ljust(8)
    assert all(32 <= ord(ch) < 127 for ch in name), name
    r[0:8] = name.encode('ascii'); r[8] = c['type']
    lo, hi = c['lo'], c['hi']
    assert 0 <= lo <= 127 and 0 <= hi <= 127, c
    r[9:13] = bytes([0, lo, 0, hi])
    r[13] = {'normal': 0, 'momentary': 0x04, 'toggle': 0x08, 'step': 0x10}.get(c.get('button'), 0)
    r[15] = c.get('display', 0)
    r[16], r[17] = c['msb'], c['lsb']
    r[18], r[19] = PORTS, CH
    r[20:22] = bytes([0, lo]); r[22] = c.get('step', 1) - 1 if c.get('button') == 'step' else 0
    r[26:41] = bytes(15)
    return bytes(r)

base = open(BASE, 'rb').read()
assert len(base) == SIZE and base[0] == 0xF0 and base[-1] == 0xF7 and base[68] == 0x5A and base[69] == 0x29
OUT.mkdir(parents=True, exist_ok=True)
for pos, t in enumerate(TEMPLATES, 1):
    m = bytearray(base)
    m[7] = 0x00          # single template into the SL's temporary memory (press WRITE to store)
    m[12] = 0x00
    m[13:48] = t['name'].ljust(35).encode('ascii'); m[48:61] = 'FZED PERF'.ljust(13).encode('ascii')
    m[65], m[66] = len(TEMPLATES), pos          # template group: size, position
    rows = t['rows']; assert len(rows) == 7 and all(len(r) == 8 for r in rows), t['name']
    flat = [c for row in rows for c in row]
    for i, c in enumerate(flat):
        o = CBASE + i * CSIZE
        m[o:o + CSIZE] = record(base[o:o + CSIZE], c)
    for i, c in zip(range(68, 72), TOUCH):
        o = CBASE + i * CSIZE; m[o:o + CSIZE] = record(base[o:o + CSIZE], c)
    for i, c in zip(range(72, 78), TRANSPORT):
        o = CBASE + i * CSIZE; m[o:o + CSIZE] = record(base[o:o + CSIZE], c)
    assert len(m) == SIZE and all(b < 0x80 for b in m[1:-1])
    (OUT / f"FZED_SL_{pos}_{t['name'].split()[-1]}.syx").write_bytes(m)

# ---- layout sheet (JSON for the editor's map and the README) -------------------------------------------
ROWS = ['Encoders', 'Pots', 'Sliders', 'Buttons above the encoders', 'Buttons below the encoders', 'Right upper buttons', 'Right lower buttons']
def describe(c):
    if c is None: return None
    if c['type'] == 1: msg = f"CC{c['lsb']}"
    elif c['msb'] == 0: msg = f"param {c['lsb']}"
    elif c['msb'] == 1: msg = f"PERF control {c['lsb']}"
    elif c['msb'] == 7: msg = f"CC{c['lsb']} (via NRPN)"
    else: msg = f"FZED NRPN {c['msb']}/{c['lsb']}"
    kind = c.get('button') or 'knob'
    extra = f", {c['settings']} settings" if c.get('settings') else ''
    return dict(name=c['name'], does=c.get('label', ''), message=msg, kind=kind + extra, low=c['lo'], high=c['hi'])
sheet = dict(channel=16, templates=[dict(name=t['name'], rows=[dict(row=ROWS[i], controls=[describe(c) for c in r]) for i, r in enumerate(t['rows'])]) for t in TEMPLATES],
             touchpad=[describe(c) for c in TOUCH], transport=[describe(c) for c in TRANSPORT])
(OUT / 'FZED_SL_LAYOUT.json').write_text(json.dumps(sheet, indent=1))
print('ok', [t['name'] for t in TEMPLATES])
