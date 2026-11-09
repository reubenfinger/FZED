# realistic 8251 model: one byte buffer, a byte arrives every PER cpu steps, overwritten if unread
# FZTIMER=1 in the environment: the FZ timer word 040Ah also runs (+20h per 200 steps, about 3,240 interrupts/s)
import os
TIMER=os.environ.get('FZTIMER')=='1'
class UART:
    def __init__(s,cpu,per=60):
        s.c=cpu; s.per=per; s.q=[]; s.buf=None; s.t=0; s.lost=0; s.err=0
        cpu.ports=s
    def feed(s,bs): s.q+=list(bs)
    def tick(s):
        s.t+=1
        if TIMER:
            s.tn=getattr(s,'tn',0)+1
            if s.tn>=200:
                s.tn=0; m=s.c.m; v=(m[0x40a]|(m[0x40b]<<8))+0x20; m[0x40a]=v&0xff; m[0x40b]=(v>>8)&0xff
        if s.q and s.t>=s.per:
            s.t=0
            if s.buf is not None: s.lost+=1; s.err=0x10
            s.buf=s.q.pop(0)
    def get(s,p,d=0):
        if p==0x1a: return 3
        if p==0xd2: return (2 if s.buf is not None else 0)|s.err
        if p==0xd0:
            b=s.buf if s.buf is not None else 0; s.buf=None; return b
        return getattr(s,'mem',{}).get(p,d)
    def __setitem__(s,k,v):
        if not hasattr(s,'mem'): s.mem={}
        if k==0x22: s.mem[k]=v
        if k==0xd2 and v&0x10: s.err=0
    def __getitem__(s,k): return 0
