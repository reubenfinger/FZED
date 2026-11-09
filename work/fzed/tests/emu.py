import sys
# Minimal 8086/186 emulator for FZ-1 optional-program testing. CS=DS=ES=SS=0.
class Halt(Exception): pass
class Bad(Exception): pass
R16=['ax','cx','dx','bx','sp','bp','si','di']
class CPU:
    def __init__(s,code,org=0x6000):
        s.m=bytearray(0x10000); s.m[org:org+len(code)]=code
        s.r={k:0 for k in R16}; s.r['sp']=0x5000
        s.ip=org; s.cf=s.zf=s.sf=s.of=0; s.df=0
        s.ports={}; s.log=[]; s.api=[]; s.steps=0; s.keyq=[]; s.writes=[]
        s.watch=None; s.ovl=False; s.codeend=org+len(code); s.ds=0; s.exited=False; s.es=0; s.pfx=None; s.wave={}
        import random; s.rnd=random.Random(1)
    def wa(s,a): return ((s.ports.get(0x22,0)&0x3f)<<16)|(a&0xffff)
    def rd8(s,a):
        if s.pfx=='es' and s.es==0x1000: return s.wave.get(s.wa(a),0)
        return s.m[a&0xffff]
    def rd16(s,a):
        if s.pfx=='es' and s.es==0x1000: return s.rd8(a)|(s.rd8(a+1)<<8)
        if s.ds: return s.rnd.randrange(65536)
        return s.m[a&0xffff]|(s.m[(a+1)&0xffff]<<8)
    def wr8(s,a,v):
        if s.pfx=='es' and s.es==0x1000: s.wave[s.wa(a)]=v&0xff; return
        a&=0xffff
        if s.watch and s.watch[0]<=a<s.watch[1]: s.writes.append((a,v&0xff))
        s.m[a]=v&0xff
    def wr16(s,a,v): s.wr8(a,v); s.wr8(a+1,v>>8)
    def g8(s,i): return s.r[R16[i&3]]>>(8*(i>>2))&0xff
    def s8(s,i,v):
        k=R16[i&3]; sh=8*(i>>2); s.r[k]=(s.r[k]&~(0xff<<sh)|((v&0xff)<<sh))&0xffff
    def fetch8(s): v=s.m[s.ip]; s.ip=(s.ip+1)&0xffff; return v
    def fetch16(s): v=s.rd16(s.ip); s.ip=(s.ip+2)&0xffff; return v
    def push(s,v): s.r['sp']=(s.r['sp']-2)&0xffff; s.wr16(s.r['sp'],v)
    def pop(s): v=s.m[s.r['sp']]|(s.m[(s.r['sp']+1)&0xffff]<<8); s.r['sp']=(s.r['sp']+2)&0xffff; return v
    def modrm(s):
        b=s.fetch8(); mod=b>>6; reg=(b>>3)&7; rm=b&7
        if mod==3: return mod,reg,rm,None
        base=[lambda:s.r['bx']+s.r['si'],lambda:s.r['bx']+s.r['di'],lambda:s.r['bp']+s.r['si'],lambda:s.r['bp']+s.r['di'],
              lambda:s.r['si'],lambda:s.r['di'],lambda:s.r['bp'],lambda:s.r['bx']]
        if mod==0 and rm==6: return mod,reg,rm,s.fetch16()
        a=base[rm]()
        if mod==1: d=s.fetch8(); a+=d-256 if d>127 else d
        elif mod==2: a+=s.fetch16()
        return mod,reg,rm,a&0xffff
    def getrm(s,w,mod,rm,a):
        if mod==3: return s.r[R16[rm]] if w else s.g8(rm)
        return s.rd16(a) if w else s.rd8(a)
    def setrm(s,w,mod,rm,a,v):
        if mod==3:
            if w: s.r[R16[rm]]=v&0xffff
            else: s.s8(rm,v)
        else:
            if w: s.wr16(a,v)
            else: s.wr8(a,v)
    def flags(s,r,w):
        m=0xffff if w else 0xff; s.zf=int(r&m==0); s.sf=int(bool(r&(m+1)>>1))
    def alu(s,op,a,b,w):
        m=0xffff if w else 0xff; top=(m+1)>>1
        if op==0: r=a+b; s.cf=int(r>m); s.of=int(bool(~(a^b)&(a^r)&top))
        elif op==2: r=a+b+s.cf; s.cf=int(r>m); s.of=int(bool(~(a^b)&(a^r)&top))
        elif op in(5,7): r=a-b; s.cf=int(r<0); s.of=int(bool((a^b)&(a^r)&top))
        elif op==3: r=a-b-s.cf; s.cf=int(r<0); s.of=int(bool((a^b)&(a^r)&top))
        elif op==1: r=a|b; s.cf=s.of=0
        elif op==4: r=a&b; s.cf=s.of=0
        elif op==6: r=a^b; s.cf=s.of=0
        r&=m; s.flags(r,w); return r
    def shift(s,op,v,n,w):
        m=0xffff if w else 0xff; bits=16 if w else 8
        for _ in range(n&0x1f):
            if op==4: s.cf=(v>>(bits-1))&1; v=(v<<1)&m
            elif op==5: s.cf=v&1; v>>=1
            elif op==2: c=(v>>(bits-1))&1; v=((v<<1)|s.cf)&m; s.cf=c
            elif op==1: s.cf=v&1; v=(v>>1)|(s.cf<<(bits-1))
            elif op==3: c=v&1; v=(v>>1)|(s.cf<<(bits-1)); s.cf=c
            elif op==0: s.cf=(v>>(bits-1))&1; v=((v<<1)|s.cf)&m
            elif op==7: s.cf=v&1; v=(v>>1)|(v&(1<<(bits-1)))
            else: raise Bad('shift op %d'%op)
        if n: s.flags(v,w)
        return v
    def cond(s,c):
        t=[s.of,s.cf,s.zf,s.cf|s.zf,s.sf,None,int(s.sf!=s.of),int(s.zf or s.sf!=s.of)][c>>1]
        if t is None: raise Bad('parity jcc')
        return t^(c&1)
    def step(s):
        s.steps+=1
        start=s.ip
        if not (0x6000<=start<s.codeend or 0xDC00<=start<0xEC00 or 0xB800<=start<0xBE00 or (s.ovl and 0xD400<=start<0xDBE0)): raise Bad('ip out of code %04x'%start)
        rep=0; s.pfx=None
        op=s.fetch8()
        while op in (0x2e,0x26,0x3e,0x36,0xf3,0xf2):
            if op in(0xf3,0xf2): rep=1
            if op==0x26: s.pfx='es'
            op=s.fetch8()
        if op==0x0f: raise Bad('0F (386) opcode at %04x'%start)
        if op<0x40 and (op&7)<6 and op not in(0x26,0x2e,0x36,0x3e):
            alu=op>>3; f=op&7; w=f&1
            if f<4:
                mod,reg,rm,a=s.modrm(); x=s.getrm(w,mod,rm,a); y=s.r[R16[reg]] if w else s.g8(reg)
                if f&2: x,y=y,x
                r=s.alu(alu,x,y,w)
                if alu!=7:
                    if f&2:
                        if w: s.r[R16[reg]]=r
                        else: s.s8(reg,r)
                    else: s.setrm(w,mod,rm,a,r)
            else:
                imm=s.fetch16() if w else s.fetch8(); x=s.r['ax'] if w else s.g8(0)
                r=s.alu(alu,x,imm,w)
                if alu!=7:
                    if w: s.r['ax']=r
                    else: s.s8(0,r)
            return
        if op==0x1e: s.push(s.ds); return
        if op==0x1f: s.ds=s.pop(); return
        if op==0x06: s.push(s.es); return
        if op==0x07: s.es=s.pop(); return
        if op in(0x0e,0x16): s.push(0); return
        if op==0x17: s.pop(); return
        if op==0x8c:
            mod,reg,rm,a=s.modrm(); s.setrm(1,mod,rm,a,s.ds if reg==3 else (s.es if reg==0 else 0)); return
        if op==0x8e:
            mod,reg,rm,a=s.modrm(); v=s.getrm(1,mod,rm,a)
            if reg==3: s.ds=v
            elif reg==0: s.es=v
            elif v!=0: raise Bad('sreg %d=%x'%(reg,v))
            return
        if 0x40<=op<0x48: k=R16[op-0x40]; c=s.cf; s.r[k]=s.alu(0,s.r[k],1,1); s.cf=c; return
        if 0x48<=op<0x50: k=R16[op-0x48]; c=s.cf; s.r[k]=s.alu(5,s.r[k],1,1); s.cf=c; return
        if 0x50<=op<0x58: k=R16[op-0x50]; v=s.r[k]; s.push(v if k!='sp' else (v)); return
        if 0x58<=op<0x60: s.r[R16[op-0x58]]=s.pop(); return
        if op==0x68: s.push(s.fetch16()); return
        if op==0x60:    # PUSHA (80186; PERF40A)
            t=s.r['sp']
            for k in R16: s.push(t if k=='sp' else s.r[k])
            return
        if op==0x61:    # POPA
            for k in reversed(R16):
                v=s.pop()
                if k!='sp': s.r[k]=v
            return
        if op==0x6a: v=s.fetch8(); s.push(v|0xff00 if v>127 else v); return
        if 0x70<=op<0x80:
            d=s.fetch8(); d=d-256 if d>127 else d
            if s.cond(op-0x70): s.ip=(s.ip+d)&0xffff
            return
        if op in(0x80,0x81,0x83):
            w=op!=0x80; mod,reg,rm,a=s.modrm(); x=s.getrm(w,mod,rm,a)
            if op==0x81: imm=s.fetch16()
            else:
                imm=s.fetch8()
                if op==0x83 and imm>127: imm|=0xff00
            r=s.alu(reg,x,imm,w)
            if reg!=7: s.setrm(w,mod,rm,a,r)
            return
        if op in(0x84,0x85):
            w=op&1; mod,reg,rm,a=s.modrm(); s.alu(4,s.getrm(w,mod,rm,a),s.r[R16[reg]] if w else s.g8(reg),w); return
        if op in(0x86,0x87):
            w=op&1; mod,reg,rm,a=s.modrm(); x=s.getrm(w,mod,rm,a); y=s.r[R16[reg]] if w else s.g8(reg)
            s.setrm(w,mod,rm,a,y)
            if w: s.r[R16[reg]]=x
            else: s.s8(reg,x)
            return
        if 0x88<=op<=0x8b:
            w=op&1; mod,reg,rm,a=s.modrm()
            if op&2:
                v=s.getrm(w,mod,rm,a)
                if w: s.r[R16[reg]]=v
                else: s.s8(reg,v)
            else: s.setrm(w,mod,rm,a,s.r[R16[reg]] if w else s.g8(reg))
            return
        if op==0x8d: mod,reg,rm,a=s.modrm(); s.r[R16[reg]]=a; return
        if op==0x8f: mod,reg,rm,a=s.modrm(); s.setrm(1,mod,rm,a,s.pop()); return
        if op==0x90: return
        if op==0x98: al=s.g8(0); s.r['ax']=al|(0xff00 if al&0x80 else 0); return
        if op==0x99: s.r['dx']=0xffff if s.r['ax']&0x8000 else 0; return
        if 0x91<=op<=0x97: k=R16[op-0x90]; s.r['ax'],s.r[k]=s.r[k],s.r['ax']; return
        if op==0xa0: s.s8(0,s.rd8(s.fetch16())); return
        if op==0xd7: s.s8(0,s.rd8((s.r['bx']+s.g8(0))&0xffff)); return
        if op==0xa1: s.r['ax']=s.rd16(s.fetch16()); return
        if op==0xa2: s.wr8(s.fetch16(),s.g8(0)); return
        if op==0xa3: s.wr16(s.fetch16(),s.r['ax']); return
        if op in(0xa4,0xab,0xaa,0xa5):
            n=s.r['cx'] if rep else 1
            sp=s.pfx                # source: ds or the override; destination: always es (wave memory when es = 1000h)
            for _ in range(n):
                if op==0xa4: s.pfx=sp; v=s.rd8(s.r['si']); s.pfx='es'; s.wr8(s.r['di'],v); s.r['si']=(s.r['si']+1)&0xffff; s.r['di']=(s.r['di']+1)&0xffff
                elif op==0xa5: s.pfx=sp; v=s.rd16(s.r['si']); s.pfx='es'; s.wr16(s.r['di'],v); s.r['si']=(s.r['si']+2)&0xffff; s.r['di']=(s.r['di']+2)&0xffff
                elif op==0xaa: s.pfx='es'; s.wr8(s.r['di'],s.g8(0)); s.r['di']=(s.r['di']+1)&0xffff
                else: s.pfx='es'; s.wr16(s.r['di'],s.r['ax']); s.r['di']=(s.r['di']+2)&0xffff
            s.pfx=sp
            if rep: s.r['cx']=0
            return
        if op==0xac: s.s8(0,s.rd8(s.r['si'])); s.r['si']=(s.r['si']+1)&0xffff; return
        if op==0xad: s.r['ax']=s.rd16(s.r['si']); s.r['si']=(s.r['si']+2)&0xffff; return
        if op==0xa8: s.alu(4,s.g8(0),s.fetch8(),0); return
        if op==0xa9: s.alu(4,s.r['ax'],s.fetch16(),1); return
        if 0xb0<=op<0xb8: s.s8(op-0xb0,s.fetch8()); return
        if 0xb8<=op<0xc0: s.r[R16[op-0xb8]]=s.fetch16(); return
        if op in(0xc0,0xc1,0xd0,0xd1,0xd2,0xd3):
            w=op&1; mod,reg,rm,a=s.modrm(); x=s.getrm(w,mod,rm,a)
            n=s.fetch8() if op<0xd0 else (1 if op<0xd2 else s.g8(1))
            s.setrm(w,mod,rm,a,s.shift(reg,x,n,w)); return
        if op==0xc3: s.ip=s.pop(); return
        if op==0xcb: raise Halt('retf')
        if op==0xcc: s.int3(); return
        if op in(0xc6,0xc7):
            w=op&1; mod,reg,rm,a=s.modrm(); v=s.fetch16() if w else s.fetch8(); s.setrm(w,mod,rm,a,v); return
        if op==0xe2:
            d=s.fetch8(); d=d-256 if d>127 else d; s.r['cx']=(s.r['cx']-1)&0xffff
            if s.r['cx']: s.ip=(s.ip+d)&0xffff
            return
        if op==0xd4:
            b=s.fetch8(); al=s.g8(0); s.r['ax']=((al//b)<<8)|(al%b); s.flags(al%b,0); return
        if op==0xe3:
            d=s.fetch8(); d=d-256 if d>127 else d
            if s.r['cx']==0: s.ip=(s.ip+d)&0xffff
            return
        if op==0xe4: p=s.fetch8(); h=s.__dict__.get('inhook'); s.s8(0,(h(p) if h else s.ports.get(p,0))&0xff); return
        if op==0xe5: p=s.fetch8(); h=s.__dict__.get('inhook'); s.r['ax']=(h(p) if h else s.ports.get(p,0))&0xffff; return
        if op==0xe6: p=s.fetch8(); s.ports[p]=s.g8(0); s.log.append(('out',p,s.g8(0))); return
        if op==0xe7: p=s.fetch8(); s.ports[p]=s.r['ax']; s.log.append(('outw',p,s.r['ax'])); return
        if op==0xe8: d=s.fetch16(); s.push(s.ip); s.ip=(s.ip+d)&0xffff; return
        if op==0xe9: d=s.fetch16(); s.ip=(s.ip+d)&0xffff; return
        if op==0xeb: d=s.fetch8(); d=d-256 if d>127 else d; s.ip=(s.ip+d)&0xffff; return
        if op in(0xf6,0xf7):
            w=op&1; mod,reg,rm,a=s.modrm(); x=s.getrm(w,mod,rm,a)
            if reg==0: s.alu(4,x,s.fetch16() if w else s.fetch8(),w)
            elif reg==3: s.setrm(w,mod,rm,a,s.alu(5,0,x,w))
            elif reg==4:
                if w: r=s.r['ax']*x; s.r['ax']=r&0xffff; s.r['dx']=r>>16; s.cf=s.of=int(r>>16!=0)
                else: r=s.g8(0)*x; s.r['ax']=r&0xffff; s.cf=s.of=int(r>>8!=0)
            elif reg==2: s.setrm(w,mod,rm,a,(~x)&(0xffff if w else 0xff))
            elif reg==5:
                if w:
                    xs=x-0x10000 if x&0x8000 else x; ax=s.r['ax']; axs=ax-0x10000 if ax&0x8000 else ax
                    r=(axs*xs)&0xffffffff; s.r['ax']=r&0xffff; s.r['dx']=r>>16
                else:
                    xs=x-0x100 if x&0x80 else x; al=s.g8(0); als=al-0x100 if al&0x80 else al
                    s.r['ax']=(als*xs)&0xffff
            elif reg==6:
                if x==0: raise Bad('div0')
                if w:
                    n=(s.r['dx']<<16)|s.r['ax']; q=n//x
                    if q>0xffff: raise Bad('div overflow')
                    s.r['ax']=q; s.r['dx']=n%x
                else:
                    n=s.r['ax']; q=n//x
                    if q>0xff: raise Bad('div overflow')
                    s.r['ax']=((n%x)<<8)|q
            elif reg==7:
                if x==0: raise Bad('idiv0')
                if w:
                    n=(s.r['dx']<<16)|s.r['ax']; n=n-(1<<32) if n&0x80000000 else n
                    d=x-0x10000 if x&0x8000 else x
                    q=abs(n)//abs(d); q=q if (n<0)==(d<0) else -q; r=n-q*d
                    if not -32768<=q<=32767: raise Bad('idiv overflow')
                    s.r['ax']=q&0xffff; s.r['dx']=r&0xffff
                else:
                    n=s.r['ax']; n=n-0x10000 if n&0x8000 else n; d=x-0x100 if x&0x80 else x
                    q=abs(n)//abs(d); q=q if (n<0)==(d<0) else -q; r=n-q*d
                    s.r['ax']=((r&0xff)<<8)|(q&0xff)
            else: raise Bad('grp3 %d'%reg)
            return
        if op==0xf8: s.cf=0; return
        if op==0xf9: s.cf=1; return
        if op==0xfc: s.df=0; return
        if op in (0xfa,0xfb): return
        if op in(0xfe,0xff):
            w=op&1; mod,reg,rm,a=s.modrm(); x=s.getrm(w,mod,rm,a)
            if reg in(0,1): c=s.cf; s.setrm(w,mod,rm,a,s.alu(0 if reg==0 else 5,x,1,w)); s.cf=c; return
            if reg==6 and w: s.push(x); return
            if reg==2 and w: s.push(s.ip); s.ip=x; return
            if reg==4 and w: s.ip=x; return
            raise Bad('grp5 %d'%reg)
        raise Bad('opcode %02x at %04x'%(op,start))
    def int3(s):
        sp=s.r['sp']; fn=s.rd16(sp); args=[s.rd16(sp+2*i) for i in range(1,7)]
        s.api.append((fn,args))
        if fn==6:
            k=s.keyq.pop(0) if s.keyq else 0
            s.r['ax']=k; s.r['bx']=k
        elif fn==0xa2:
            p=args[3]; t=bytes(s.m[p:p+24]).split(b'\0')[0].decode('latin1')
            s.log.append(('lcd',args[2],t))
        elif fn==0x57: s.exited=True
        elif fn==0x33:
            if args[0]==0x90: s.m[0x5420]=1
            s.log.append(('note',hex(args[1]),args[2]))
