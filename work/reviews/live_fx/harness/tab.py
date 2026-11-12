import json, sys
a = json.load(open(sys.argv[1])); b = json.load(open(sys.argv[2]))
print('%-7s %-6s %-6s | %8s %8s %6s | %8s %8s %6s | %7s %7s | %7s %7s' % ('case', 'loopA', 'loopB', 'passA', 'passB', 'v30%', 'p86A', 'p86B', '86%', 'in/wA', 'in/wB', '86in/wA', '86in/wB'))
for k in a:
    x, y = a[k], b.get(k)
    if not x or not y: continue
    px, py = x['acc']['pass'], y['acc']['pass']; ix, iy = x['acc']['inner'], y['acc']['inner']
    f = lambda t, j: t[j] / max(1, t[0])
    print('%-7s %-6s %-6s | %8.0f %8.0f %5.0f%% | %8.0f %8.0f %5.0f%% | %7.1f %7.1f | %7.1f %7.1f' % (k, x['loop'][:6], y['loop'][:6], f(px, 1), f(py, 1), 100 * (f(py, 1) / f(px, 1) - 1), f(px, 2), f(py, 2), 100 * (f(py, 2) / f(px, 2) - 1), f(ix, 1) / 128, f(iy, 1) / 128, f(ix, 2) / 128, f(iy, 2) / 128))
