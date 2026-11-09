import json
E=json.load(open('echo_editor.json'))
L=json.load(open('lcd_fzed.json')); L.update(json.load(open('lcd_fzed_sl.json')))
n=bad=0
for k,r in L.items():
    first=True
    for (raw,lab,rows),(raw2,e3,e4) in zip(r['res'],E[k]):
        last={}
        for row,col,t in rows: last[row]=t.strip()
        f3,f4=last.get(3,''),last.get(4,'')
        n+=1
        # the scan only saw what FZED drew after this value: an editor line FZED didn't redraw can't be compared
        ok3 = f3==e3 or (f3=='' ) ; ok4 = f4==e4 or f4==''
        if not(ok3 and ok4) or (e4=='' and f4) or (e3=='' and f3):
            bad+=1; print(f"{k:14} {r['label'][:16]:16} {raw:3} FZ {f3!r}/{f4!r}  ED {e3!r}/{e4!r}")
print(n,'compared',bad,'differ')
