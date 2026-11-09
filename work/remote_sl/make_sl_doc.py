#!/usr/bin/env python3
"""Write the ReMOTE SL layout as Markdown (for the manual and the template folder) from fzed_sl_layout.json."""
import json, sys
L = json.load(open(sys.argv[1]))
def cell(c): return '-' if c is None else f"{c['name'].strip()} ({c['message']})"
def table(rows):
    out = ['| Row | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |', '| --- | --- | --- | --- | --- | --- | --- | --- | --- |']
    for r in [rows[i] for i in (3, 0, 4, 1, 2, 5, 6)]: out.append(f"| {r['row']} | " + ' | '.join(cell(c) for c in r['controls']) + ' |')
    return '\n'.join(out)
parts = []
for t in L['templates']:
    parts.append(f"### {t['name']}\n\n{table(t['rows'])}\n")
parts.append('### All three templates\n\n| Control | Name | Sends |\n| --- | --- | --- |\n' +
             '\n'.join(f"| Touchpad {['X1','Y1','X2','Y2'][i]} | {c['name'].strip()} | {c['message']} |" for i, c in enumerate(L['touchpad'])) + '\n' +
             '\n'.join(f"| Transport {n} | {c['name'].strip()} | {c['message']}{' (' + c['does'] + ')' if c['does'] else ''} |" for n, c in zip(['Rewind','Forward','Stop','Play','Record','Loop'], L['transport'])) + '\n')
print('\n'.join(parts))
