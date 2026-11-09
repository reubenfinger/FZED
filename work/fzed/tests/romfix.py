# PERF38W test-model correction (PERF38V/Core69 appraisal V01/V06), applied to a capture-test source text:
# - API45 (record setup) records from the allocation start to the allocation end (voice +00h / +04h), as the ROM at
#   F000:2566 programs the gate array, not the editable sample bounds (+08h / +0Ch);
# - API47 (record stop) ends the recording at once;
# - words per ms = 36 / 2^rate (4.5 at 4.5k, not 4).
def romfix(src):
    a = "st['recw'] = (M16(v + 0xc) | ((M16(v + 0xe) & 0x1f) << 16)) - (M16(v + 8) | ((M16(v + 0xa) & 0x1f) << 16))"
    assert src.count(a) == 1
    src = src.replace(a, "st['recw'] = (M16(v + 4) | ((M16(v + 6) & 0x1f) << 16)) - (M16(v + 0) | ((M16(v + 2) & 0x1f) << 16))")
    a = "ms = st['recw'] / (36 >> c.m[0x4d9])"; assert src.count(a) == 1
    src = src.replace(a, "ms = st['recw'] / (36 / (1 << c.m[0x4d9]))")
    a = "    if fn == 47: st['seq'].append(('stop', a[2]))"; assert src.count(a) == 1
    src = src.replace(a, "    if fn == 47: st['seq'].append(('stop', a[2], c.steps)); st['rec0'] = None")
    return src
