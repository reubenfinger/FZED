import json, sys
a = json.load(open(sys.argv[1])); b = json.load(open(sys.argv[2]))
tot = bad = 0; unch = 0
print('coverage old', a.pop('_cov', None)); print('coverage new', b.pop('_cov', None))
for k in a:
    x, y = a[k], b.get(k)
    if not isinstance(x, dict) or not isinstance(y, dict): print('skip', k, x if not isinstance(x, dict) else y); continue
    tot += 1
    d = [(i, p, q) for i, (p, q) in enumerate(zip(x['voice'], y['voice'])) if p != q]
    r = x['restored'] != y['restored']
    if x['voice'] == x['restored']: unch += 1
    if d or r:
        bad += 1
        s16 = lambda v: v - 65536 if v > 32767 else v
        mx = max((abs(s16(p) - s16(q)) for _, p, q in d), default=0)
        print('DIFF', k, 'words', len(d), 'max', mx, 'restored differs' if r else '', d[:3])
print('cases', tot, 'different', bad, '(cases where the effect left the voice unchanged: %d)' % unch)
