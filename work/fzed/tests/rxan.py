import json, collections, sys
R = json.load(open(sys.argv[1] if len(sys.argv)>1 else 'rxscan_fzed.json'))
MAP = {}
for l in open('fzed.map'):
    p = l.split()
    if len(p) >= 2:
        try: MAP[p[-1]] = int(p[0][-4:], 16)
        except: pass
SYM = sorted((v, k) for k, v in MAP.items())
def name(a):
    if 0x2288 <= a < 0x2288 + 64 * 0xc0:
        n, o = divmod(a - 0x2288, 0xc0); return f'v{n}+{o:02X}'
    best = None
    for v, k in SYM:
        if v <= a: best = (v, k)
        else: break
    return f'{best[1]}+{a-best[0]:X}' if best and a - best[0] < 0x80 else f'{a:04X}'
cnt = collections.Counter()
for k, r in R.items():
    for a in set(r.get('value', [])): cnt[a] += 1
gen = {a for a, n in cnt.items() if n > len(R) * 0.15}
print('generic:', sorted(name(a) for a in gen))
for k, r in R.items():
    if 'note' in r: print(k, r['label'], r['note']); continue
    sv = [a for a in r['value'] if a not in gen]; sa = [a for a in r['any'] if a not in gen]
    tag = 'VALUE' if sv else ('ANY' if sa else 'NONE')
    print(f"{tag:5} {k:16} {r['label']:22} {str(r['seq']):42} {[name(a) for a in (sv or sa)[:5]]}")
