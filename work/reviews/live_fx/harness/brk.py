import json, sys
r = json.load(open(sys.argv[1]))
names = ['pass', 'l6372', 'matrix', 'captick', 'rvpatch', 'lvrunx', 'findph', 'lvchk_sweep', 'lvseg', 'rd', 'inner', 'wr', 'parse']
print('%-7s %-5s' % ('case', 'loop'), ' '.join('%8s' % n[:8] for n in names), '   waits/pass  rom/pass')
for k, v in r.items():
    if not v: continue
    a = v['acc']; n = a['pass'][0]
    print('%-7s %-5s' % (k, v['loop'][:5]), ' '.join('%8.0f' % (a[x][1] / n) for x in names), '  %6.0f' % (a['pass'][3] / n), {kk: round(vv / n, 2) for kk, vv in v['rom'].items()}, '' if not v['unknown'] else v['unknown'])
