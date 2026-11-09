import sys; import os; sys.path.insert(0,os.getcwd())
from emu import CPU,Halt,Bad
from uart import UART
full=open('galab2.bin','rb').read()
V1=0x2288+0xc0; EV=0x2288+0xc0*5; BANK=0x0e08
def mk(evmode):
    c=CPU(full[:1024]+bytes(3072)); c.codeend=0x7000; c.push(0xdead)
    c.wr16(0xe04,EV); c.wr16(0xe06,0); c.wr16(0xe02,5)
    c.wr16(EV+0x10,evmode); c.wr16(EV+12,0x3e38); c.wr16(EV+14,2)
    for i in range(0x14,0xb2): c.m[EV+i]=(i*7)&0x7f
    c.wr16(0xdfe,BANK); c.wr16(BANK,1); c.wr16(BANK+0x202,V1)
    c.wr16(0x9d8,0x20); c.calls=[]; c.genplay=1
    oi=c.int3
    def i3():
        sp=c.r['sp']; fn=c.rd16(sp); a=[c.rd16(sp+2*i) for i in range(1,5)]
        if fn==0xbf:
            pcl,off=a[0],a[1]; c.m[off:off+1024]=(full[(pcl-17)*1024:]+bytes(1024))[:1024]; c.r['ax']=0; return
        if fn in (45,46,47,48,117,119):
            c.calls.append(fn); c.r['ax']=c.r['bx']=0
            if fn==119: c.wr16(EV+0x10,0)
            if fn==117: c.wr16(EV+8,0); c.wr16(EV+10,0); c.wr16(EV+12,0x5f90); c.wr16(EV+14,1)
            return
        if fn==49: c.r['ax']=c.r['bx']=c.genplay; return
        oi()
    c.int3=i3; return c
def midi(c,*bs):
    wp=c.rd16(0x9d8)
    for b in bs: c.m[0x8d6+wp]=b; wp=(wp&0xff00)|((wp+1)&0xff)
    c.wr16(0x9d8,wp)
def run(c,u,n):
    for _ in range(n):
        if c.exited: return
        u.tick(); c.step()
def lcd(c,k=3): return [x[2] for x in c.log if x[0]=='lcd'][-k:]
print('=== empty voice, record, assign, perf CCs, ESC')
c=mk(0); u=UART(c,per=300); run(c,u,3_000_000); print(lcd(c,4))
midi(c,0xb0,74,0x34); run(c,u,300000); print('CC74 before take ->',hex(c.m[EV+0x76]),'(ignored expected)')
midi(c,0xb0,106,0x50); run(c,u,300000); print('arm',lcd(c,2),c.calls)
c.calls=[]; u.feed([0xb0,107,0x7f]); run(c,u,1_000_000); print('rec',lcd(c,2),c.calls)
c.genplay=0; run(c,u,1_000_000); print('done',lcd(c,2),'mode',hex(c.rd16(EV+0x10)),'bank area0 ->',hex(c.rd16(BANK+0x202)),'(EV=%x)'%EV)
c.genplay=1
midi(c,0xb0,74,0x34); run(c,u,300000); print('CC74 after take ->',hex(c.m[EV+0x76]))
midi(c,0xb0,78,0); run(c,u,300000); print('CC78 attack ->',hex(c.m[EV+0x7a]))
c.calls=[]; midi(c,0xb0,106,0x50); run(c,u,300000); print('re-arm after DONE (value 80):',lcd(c,1),c.calls)
c.calls=[]; u.feed([0xb0,107,0x7f]); run(c,u,800000); c.genplay=0; run(c,u,800000); print('retake',lcd(c,1),'bank',hex(c.rd16(BANK+0x202)))
c.keyq=[0x15]; run(c,u,500000); print('ESC exit',c.exited,'bank restored ->',hex(c.rd16(BANK+0x202)),'take kept mode',hex(c.rd16(EV+0x10)))
print('=== empty voice, record, ENTER keeps assignment')
c=mk(0); u=UART(c,per=300); run(c,u,3_000_000)
midi(c,0xb0,106,0x50); run(c,u,300000); u.feed([0xb0,107,0x7f]); run(c,u,800000); c.genplay=0; run(c,u,800000)
midi(c,0xb0,74,0x22); run(c,u,300000)
c.keyq=[0x14]; run(c,u,500000); print('ENTER exit',c.exited,'bank ->',hex(c.rd16(BANK+0x202)),'cutoff kept',hex(c.m[EV+0x76]))
print('=== non-empty voice: perf behaviour, USED protection, ESC restore')
c=mk(0x1d7); u=UART(c,per=300); orig=bytes(c.m[EV:EV+0xc0]); run(c,u,3_000_000); print(lcd(c,3))
for cc,v in [(74,0x34),(70,0x50),(77,0x40),(78,0)]: midi(c,0xb0,cc,v); run(c,u,300000)
print('writes ok:',hex(c.m[EV+0x76]),hex(c.rd16(EV+0x10)),hex(c.m[EV+0x7a]))
midi(c,0xb0,106,0x50); run(c,u,300000); print('arm on used voice (80):',lcd(c,1))
c.keyq=[0x15]; run(c,u,500000); print('ESC',c.exited,'restored',bytes(c.m[EV:EV+0xc0])==orig,'bank untouched',hex(c.rd16(BANK+0x202)))
