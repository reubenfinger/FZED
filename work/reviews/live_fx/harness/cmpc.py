import json, sys, math
a = json.load(open(sys.argv[1])); b = json.load(open(sys.argv[2])); a.pop('_cov', None); b.pop('_cov', None)
s16 = lambda v: v - 65536 if v > 32767 else v
for k in b:
    x, y = a.get(k), b[k]
    if not isinstance(x, dict) or not isinstance(y, dict): continue
    d = [s16(p) - s16(q) for p, q in zip(x['voice'], y['voice'])]
    nz = sum(1 for v in d if v); mx = max(abs(v) for v in d); rms = math.sqrt(sum(v * v for v in d) / len(d))
    print('%-52s words differing %4d/%d  max %5d  rms %7.1f (%.0f dB re full scale)' % (k, nz, len(d), mx, rms, 20 * math.log10(max(rms, 1e-9) / 32768)))
