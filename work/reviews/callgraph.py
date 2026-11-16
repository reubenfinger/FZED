import re,sys,collections
order=[]
def load(fn,seen=()):
    for ln,l in enumerate(open(fn,errors='replace'),1):
        m=re.match(r'\s*%include\s+"(?:fx/)?([^"]+)"',l)
        if m: load('fx/'+m.group(1)); continue
        order.append((fn,ln,l.rstrip('\n')))
load('fzed.asm')
funcs=collections.OrderedDict(); cur=None
for fn,ln,l in order:
    code=l.split(';')[0]
    m=re.match(r'^([A-Za-z_][A-Za-z0-9_@.]*):(.*)$',code)
    if m and not m.group(1).startswith('.'):
        cur=m.group(1); funcs[cur]={'loc':(fn,ln),'lines':[]}; code=m.group(2)
    else:
        m2=re.match(r'^(\.[A-Za-z0-9_]+):(.*)$',code)
        if m2: code=m2.group(2)
    if cur and code.strip() and not re.search(r'\bequ\b',code): funcs[cur]['lines'].append((fn,ln,code.strip(),l))
names=list(funcs)
edges={}
for i,n in enumerate(names):
    e=set(); L=funcs[n]['lines']
    for fn,ln,c,_ in L:
        for t in re.findall(r'\b(?:call|jmp|j[a-z]{1,3}|loop|push word|mov [a-z]{2},|dw)\s+(?:near |short )?([A-Za-z_.@][A-Za-z0-9_@.,]*)',c):
            for tt in t.split(','):
                tt=tt.split('.')[0] if not tt.startswith('.') else ''
                if tt in funcs and tt!=n: e.add(tt)
        m=re.match(r'APIC\s+(\w+)',c)
        if m: e.add('APIC_'+m.group(1))
    last=L[-1][2] if L else ''
    if not re.match(r'(ret|retf|iret|jmp)\b',last) and not re.match(r'(db|dw|times|%)',last) and i+1<len(names): e.add(names[i+1])
    edges[n]=e
def reach(start,stop=()):
    par={start:None}; q=[start]
    while q:
        x=q.pop(0)
        for y in sorted(edges.get(x,())):
            if y not in par:
                par[y]=x
                if y not in stop: q.append(y)
    return par
def path(par,t):
    p=[]
    while t: p.append(t); t=par[t]
    return ' <- '.join(p)
if __name__=='__main__':
    start=sys.argv[1]; par=reach(start)
    print(len(par),'reachable from',start)
    print(sorted(par))
    for t in sys.argv[2:]:
        print(t, '=>', path(par,t) if t in par else 'NOT REACHABLE')
    pat=re.compile(r'KSB|DBUF|TBUF|0xd[4-9a-b][0-9a-f]{2}\b|OVCALL',re.I)
    for n in par:
        if n in funcs:
            for fn,ln,c,_ in funcs[n]['lines']:
                if pat.search(c): print('  HIT',n,fn,ln,c, '   via', path(par,n))
