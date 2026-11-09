import math
src=open('t8g2.py').read().replace('galab2.bin','perf24.bin').replace('c.codeend=0x7000','c.codeend=0x8000')
exec(src.split("print('=== empty voice, record, assign")[0])
c=mk(0x1d7); u=UART(c,per=300); c.m[0xdeb]=0
S,E=0x1000,0x2000
c.wr16(EV+8,S); c.wr16(EV+10,0); c.wr16(EV+12,E); c.wr16(EV+14,0)
top=[0x20000]; calls=[]
prev=c.int3
def i3():
    sp=c.r['sp']; fn=c.rd16(sp); a=[c.rd16(sp+2*i) for i in range(1,5)]
    if fn==117:
        v=a[0]; size=a[2]|(a[3]<<16); st=top[0]; top[0]+=size
        en=st+size-8
        for o,val in ((0,st),(4,st+size),(8,st),(12,en)):
            c.wr16(v+o,val&0xffff); c.wr16(v+o+2,val>>16)
        calls.append(('alloc',hex(v),size)); c.r['bx']=0; c.r['ax']=0; return
    if fn==169:
        v=a[0]; calls.append(('del',hex(v)))
        for i in range(0xc0): c.m[v+i]=0
        c.r['bx']=0; return
    if fn==170: calls.append(('delun',hex(a[0]))); c.r['bx']=0; return
    prev()
c.int3=i3
run(c,u,3_000_000)
for w in range(S,E):
    b=w*2; v=w&0xffff; c.wave[b]=v&0xff; c.wave[b+1]=v>>8
def wv(w): b=w*2; return c.wave.get(b,0)|(c.wave.get(b+1,0)<<8)
def lcd(n=2): return [x[2] for x in c.log if x[0]=='lcd'][-n:]
