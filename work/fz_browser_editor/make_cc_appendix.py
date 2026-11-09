"""Build the manual's CC appendix (Appendix A) from profile.js and the editor's page layouts, in menu page order."""
import json, re, subprocess, pathlib
root = pathlib.Path(__file__).resolve().parents[2]; app = root / 'outputs/FZED'
P = json.loads(subprocess.run(['node', '-e', 'global.window={};require(process.argv[1]);console.log(JSON.stringify(Object.values(window)[0]))',
                               str(app / 'profile.js')], capture_output=True, text=True, check=True).stdout)['controls']
js = (app / 'editor.js').read_text()
lit = lambda name: subprocess.run(['node', '-e', 'console.log(JSON.stringify(' + re.search(r'const ' + name + r'\s*=\s*(.*?);[ \t]*(?://[^\n]*)?\n', js, re.S).group(1) + '))'],
                                  capture_output=True, text=True, check=True).stdout
groups = json.loads(lit('groups')); layouts = json.loads(lit('pageLayouts')); bankCodes = json.loads(lit('bankCodes'))
fxOrder = json.loads(lit('fxOrder')); fxUsed = {int(k): v for k, v in json.loads(lit('fxUsedSlots')).items()}
NICE = {}

def title(s):
    s = NICE.get(s, s)
    keep = {'DCF', 'DCA', 'DCQ', 'LFO', 'LFO1', 'LFO2', 'FX', 'KS', 'DC', 'FZED', 'ON', 'OFF'}
    w1 = lambda w: w if w in keep or re.fullmatch(r'[0-9+>-]+', w) else w.capitalize()
    return ' '.join('/'.join(w1(x) for x in w.split('/')) for w in s.split()).replace('Lvl', 'Level').replace('Flt', 'Filter')

CMD = {   # commands: the exact messages the editor sends (commandPackets in editor.js) and what FZED does with them
    108: ('FZED 7 to enter, CC108 to leave', 'FZED 7 = 64-127 enters capture; CC108 = 0-63 leaves it'),
    1547: ('FZED 11', '0-127, spread over the voices that have sound; the picked voice shows on line 2'),
    1548: ('FZED 12', '64-127 selects the picked voice (voice mode only)'),
    1549: ('FZED 14, then FZED 13', 'FZED 13 = 0-63 leaves as ESC (edits put back). To leave as ENTER, first set FZED 14 to what is kept (0-42 the sound edits, 43-85 all of the edit voice, 86-127 everything, bank voices too), then FZED 13 = 64-127'),
    1551: ('FZED 15', '64-127 lets go of the current chop; its slices stay in the bank as plain voices'),
}
def msg(seq, d=None):
    if d is not None and d['code'] in CMD and (d['code'] != 108 or d['group'] == 'capture'): return CMD[d['code']][0]
    if len(seq) == 1: return f'CC{seq[0][0]}'
    if len(seq) == 2 and seq[0][0] == 10 and seq[1] == [11, None]: return f'P{seq[0][1]}'
    if len(seq) == 4 and seq[:3] == [[10, 88], [11, seq[1][1]], [10, 89]]: return f'FZED {seq[1][1]}'
    if all(x[1] is None for x in seq): return ' + '.join(f'CC{x[0]}' for x in seq) + ' (same value)'
    if len(seq) == 4 and seq[0][0] == 10 and seq[2][0] == 10: return f'P{seq[0][1]} = {seq[1][1]}, then P{seq[2][1]}'
    return ', '.join(f'CC{a}={"value" if b is None else b}' for a, b in seq)

def rng(ws):
    ws = sorted(set(ws)); runs = []
    for w in ws:
        if runs and w == runs[-1][1] + 1: runs[-1][1] = w
        else: runs.append([w, w])
    return ', '.join(f'{a}' if a == b else f'{a}-{b}' for a, b in runs)
def clean(t):
    t = re.sub(r'["\\]', '', t).strip()
    return re.sub(r'\b([A-G]#?) (\d)$', r'\1\2', re.sub(r'\b([A-G]#?) ?-$', r'\1-1', t.replace('NOTE ', '')))
def vals(d):
    if d['code'] in CMD and (d['code'] != 108 or d['group'] == 'capture'): return CMD[d['code']][1]
    wv = d['wireValues']; lab = [clean(x) for x in d['values']]; order = []
    by = {}
    for r in range(128):
        t = lab[r].strip()
        if t not in by: order.append(t); by[t] = []
        by[t].append(wv[r])
    if d['code'] == 103 and d['group'] == 'record':
        r0 = d['rateValues'][0]; return f'{rng(wv)} ({r0[0]} to {r0[127]} at 36K; 2x at 18K, 4x at 9K, 8x at 4.5K)'
    if len(order) == 1: return rng(wv)
    if len(order) <= 16: return '; '.join(f'{t} {rng(by[t])}' for t in order)
    a, b = lab[0].strip(), lab[127].strip()
    if d['code'] == 103 and d['group'] == 'record':
        r0 = d['rateValues'][0]; return f'{rng(wv)} ({r0[0]} to {r0[127]} at 36K; 2x at 18K, 4x at 9K, 8x at 4.5K)'
    m = re.search(r' \(.*\)$', a)
    if m and b.endswith(m.group(0)): return f'{rng(wv)} ({a[:m.start()]} to {b[:-len(m.group(0))]}; {m.group(0)[2:-1].lower()})'
    return rng(wv) if a.startswith('CC') else f'{rng(wv)} ({a} to {b})'

def page_controls(g):
    C = [d for d in P if d['group'] == g]
    if g == 'capture':
        prim = [d for d in P if d['group'] == 'capture' and d['variant'] == 1 and d['code'] != 110]
        sec = [dict(d, slot=14 if d['code'] == 41 else d['slot'] + 10) for d in P if d['group'] == 'capture2' and d['variant'] == 2 and (d['slot'] < 4 or d['code'] == 41)]
        return {0: prim + sec}
    if g == 'bank':
        out = []
        for i, (code, grp) in enumerate(bankCodes):
            d = next((c for c in P if c['code'] == code and c['group'] == grp), None)
            if d: out.append(dict(d, slot=i))
        return {0: out}
    if g == 'fx': return {v: [d for d in C if d['variant'] == v and d['code'] not in (100, 101) and d['slot'] in fxUsed.get(v, [])] for v in fxOrder}
    bankOnly = set(json.loads(re.search(r'bankOnly=new Set\((\[[^\]]*\])\)', js).group(1)))
    C = [d for d in C if d['code'] != 1280 and not (g == 'voice' and d['code'] in bankOnly)]
    vs = {}
    for d in C: vs.setdefault(d['variant'], []).append(d)
    return vs

def ordered(g, ctl):
    spec = layouts.get(g); by = {d['slot']: d for d in ctl}; out = []; used = set()
    if spec:
        for row in spec:
            for t, slots in row:
                if t is None: continue
                if slots == '*': out.append('*'); continue
                for s in slots:
                    if s in by: out.append(by[s]); used.add(s)
    rest = [d for d in ctl if d['slot'] not in used]
    if '*' in out: i = out.index('*'); out[i:i + 1] = rest
    else: out += rest
    return out

L = ['## Appendix A: MIDI CC Reference', '',
     'Every FZED control, page by page in menu order and, within a page, in the order the editor shows it. '
     'All messages go on the FZ\'s MIDI channel. The **Message** column uses three forms:', '',
     '- **CCn**: an ordinary MIDI control change n carrying the value.',
     '- **Pn**: FZ parameter n. Send CC10 = n, then CC11 = the value. Further CC11 messages keep editing parameter n until another CC10 arrives.',
     '- **FZED k**: FZED\'s own control k. Send CC10 = 88, CC11 = k, then CC10 = 89, CC11 = the value.', '',
     'The **Values** column gives the value FZED receives and what it means. Where a range is shown for each setting, any value in the range selects it; the editor sends the middle of the range. '
     'A few CCs mean different things on different pages: CC96, 97 and 99 are Chop controls until capture is on, then chord controls; CC102-110 are Record controls until capture is on, then capture controls; '
     'CC113-116 and CC94/95 follow the effect chosen with CC112. Commands (Make Slices, Render, Record Start and similar) act when their value enters the command range and must return to the re-arm range before they act again.', '']
n = 0
for g, name in groups:
    if g == 'user': continue
    n += 1; vs = page_controls(g)
    L += [f'### A.{n} {name}', '']
    if g == 'fx':
        common = ordered('fx', vs[fxOrder[0]])
        L += ['| Control | Message | Values |', '| --- | --- | --- |']
        f0 = next(d for d in common if d['code'] == 112)
        L.append(f'| FX Type | {msg(f0["sequence"])} | ' + '; '.join(f'{f0["values"][r].strip()} {rng(range(r, r2))}' for r, r2 in
                 [(b * 128 // 15 + (b * 128 % 15 > 0), (b + 1) * 128 // 15 + ((b + 1) * 128 % 15 > 0)) for b in range(15)]) + ' |')
        for code, lab in ((117, 'Dry/Wet Mix'), (119, 'Live FX'), (118, 'Render')):
            d = next(d for d in P if d['group'] == 'fx' and d['variant'] == 1 and d['code'] == code)
            L.append(f'| {lab} | CC{code} | {vals(d)} |')
        for code, lab in ((100, 'Delete Unused'), (101, 'Normalise')):
            d = next(d for d in P if d['group'] == 'fx' and d['variant'] == 1 and d['code'] == code)
            L.append(f'| {lab} (button) | CC{code} | {vals(d)} |')
        L += ['', 'Effect parameters, by effect (in FX Type order):', '', '| Effect | Control | Message | Values |', '| --- | --- | --- | --- |']
        for v in fxOrder:
            eff = next(d for d in vs[v] if d['code'] == 112)
            nm = eff['values'][min(127, (fxOrder.index(v) * 128 + 64) // 15)].strip()
            for d in ordered('fx', vs[v]):
                if d['code'] in (112, 117, 118, 119) or d['label'].startswith('NOT USED'): continue
                L.append(f'| {title(nm)} | {title(d["label"].replace(" (RENDER)", ""))} | {msg(d["sequence"], d)} | {vals(d)} |')
            if v == 8: pass
        L.append('')
        continue
    L += ['| Control | Message | Values |', '| --- | --- | --- |']
    if g == 'matrix':
        for v, kind in ((0, 'Source'), (2, 'Destination'), (1, 'Amount')):
            ds = sorted(vs[v], key=lambda d: d['slot']); ps = [d['sequence'][0][1] for d in ds]
            L.append(f'| Route 1-10 {kind} | P{ps[0]}-P{ps[-1]} (route n = P{ps[0] - 1}+n) | {vals(ds[0])} |')
        L.append(''); continue
    if g in ('envelope', 'controllers'):
        first = min(vs); rows = ordered(g, vs[first])
        for d in rows:
            same = [x for v in sorted(vs) for x in vs[v] if x['slot'] == d['slot']]
            seqs = [x['sequence'] for x in same]
            if all(s == seqs[0] for s in seqs): L.append(f'| {title(re.sub(" STEP [0-9]$", "", d["label"]))} | {msg(d["sequence"], d)} | {vals(d)} |'); continue
            if g == 'envelope':
                ps = [s[0][1] for s in seqs]
                L.append(f'| {title(d["label"].replace("STEP 1", "Step 1-8"))} | P{ps[0]}-P{ps[-1]} (step n = P{ps[0] - 1}+n) | {vals(d)} |')
            else:
                lab = re.sub('^(MW|FOOT|AT) ', '', d['label'])
                L.append(f'| {title(lab)} | ' + ', '.join(f'{msg(s)} {w}' for s, w in zip(seqs, ('mod wheel', 'foot', 'aftertouch'))) + f' | {vals(d)} |')
        L.append(''); continue
    for v in sorted(vs):
        for d in ordered(g, vs[v]):
            L.append(f'| {title(d["label"])} | {msg(d["sequence"], d)} | {vals(d)} |')
    L.append('')
text = '\n'.join(L).rstrip() + '\n'
man = (app / 'FZED_MANUAL.md').read_text()
a = man.find('## Appendix A: MIDI CC Reference'); b = man.find('## Software And Data')
man = (man[:a] if a >= 0 else man[:b]) + text + '\n' + man[b:]
(app / 'FZED_MANUAL.md').write_text(man)
print('appendix', len(L), 'lines,', n, 'pages')
