"""Add FZED page presets (stretch, pattern, FX, LFO 1) to the bundled USER_FZ.BIN, after the 26 Gills presets.
Each preset holds only its page's settings, so it layers onto the current voice. Stretch values go in bytes 530-541
('S' + Gills STRETCH-view keys 0-8, 10, 9), which Gills Core 109 replays; older cores ignore them."""
import json,hashlib,base64,pathlib
root=pathlib.Path(__file__).resolve().parents[2];app=root/'outputs/FZED'
prof=json.loads((app/'profile.js').read_text().split(' = ',1)[1].rstrip(';\n'))
C=prof['controls']
EXT=[0,1,2,3,4,5,6,7,8,10,9]
def ctl(code,fx=None):
    m=[d for d in C if d['code']==code and not d.get('synthetic') and (fx is None or d['group']!='fx' or d['variant']==fx)]
    assert m,code; return m[0]
def step(code,i):return ctl(code)['steps'][i]
SEG=lambda n:step(1536,n-2)
def stretch(name,seg,time,grain,xfade,snap,sus,nxt,order,skew):
    sus_raw=((sus*128+64)//(seg+1))
    vals={0:SEG(seg),1:step(1537,time),2:grain,3:xfade,4:step(1540,snap),5:sus_raw,6:step(1542,nxt),7:step(1543,order),8:step(1544,skew),9:step(1545,1)}
    return name,{},vals
P=[]
# STRETCH: segments, time step (0.02..19.5 s list), grain raw, crossfade raw, snap, sustain segment (0 none), next (0 trace,1 trace+cut,2 skip,3 skip+cut), order step, skew step (16 even)
P.append(stretch('ST TIMESTRCH',8,8,127,0,1,0,0,0,16))
P.append(stretch('ST REVERSE',4,11,63,10,1,0,3,1,16))
P.append(stretch('ST SHUFFLE',8,4,31,0,1,0,3,5,16))
P.append(stretch('ST STUTTER',8,2,4,0,1,0,0,0,8))
P.append(stretch('ST SLOWDOWN',6,9,127,0,1,0,0,0,28))
P.append(stretch('ST FREEZE',2,31,12,0,1,1,0,0,16))
P.append(stretch('ST PINGPONG',8,6,63,0,1,0,2,2,16))
# PATTERN (+ matrix route 10: source PATTERN, amount, destination)
def pattern(name,pat,rate,smooth,dest,amount):
    return name,{128+8:pat*8+4,128+9:rate,128+87:smooth*16+8,128+99:12*8+4,128+109:amount,128+119:dest*8+4},{}
P.append(pattern('PT 8THS GATE',1,20,2,3,127))
P.append(pattern('PT TRANCE',6,14,1,3,127))
P.append(pattern('PT GALLOPFLT',7,24,4,1,110))
P.append(pattern('PT RAMPPITCH',14,30,3,4,90))
P.append(pattern('PT BROKEN',13,18,2,3,120))
# FX (type step order: TAPEHACK, WAVEFOLDER, XOVER FUZZ, RECTIFIER, DECIMATOR, LINEAR CRUSH, BIT MANGLE, ECHO / COMB, POSITION,
# RING MOD, TUBE2, KARPLUS-STRONG, FILTER, TAPEHACK > POCKEY2, POCKEY2)
def fx(name,t,**kv):
    v={112:(t*128+64)//15};v.update({int(k[1:]):x for k,x in kv.items()});return name,v,{}
P.append(fx('FX TAPE SOFT',0,c115=26,c116=110,c117=100,c114=0))
P.append(fx('FX TAPEDRIVE',0,c115=64,c116=90,c117=127,c114=0))
P.append(fx('FX FOLD',1,c115=50,c116=100,c117=127,c114=0))
P.append(fx('FX TUBE',10,c115=60,c116=80,c117=127,c114=0))
P.append(fx('FX RING LOW',9,c94=20,c95=0,c117=100,c114=0))
P.append(fx('FX KS PLUCK',11,c94=60,c95=100,c117=127,c114=0))
# LFO 1
def lfo(name,wave,rate,pitch,amp,flt,res=0):
    return name,{50:wave,73:rate,53:pitch,54:amp,55:flt,56:res},{}
P.append(lfo('LF VIBRATO',0,70,18,0,0))
P.append(lfo('LF TREMOLO',3,80,0,50,0))
P.append(lfo('LF WOBBLE',0,60,0,0,70,20))
import os
gills=pathlib.Path(os.environ.get('GILLS',str(root.parent/'Gills')))
b=bytearray((gills/'outputs/SD_CARD_PERF38H/USER_FZ.BIN').read_bytes());src=app/'USER_FZ.BIN'
used=[i for i in range(100) if b[16+i*544+13]]
assert len(used)==26 and used==list(range(26)),used
slot=26
for name,vals,ext in P:
    s=bytearray(544);s[0:12]=name.ljust(12)[:12].encode();s[12]=4;s[13]=1;s[18:530]=b'\xff'*512
    for i,w in vals.items():s[18+i]=w;s[274+i]=w
    if ext:
        s[530]=0x53;s[531:542]=b'\xff'*11
        for k,w in ext.items():s[531+EXT.index(k)]=w
    n=len(vals);s[14]=n&255;s[15]=n>>8;s[16]=n&255;s[17]=n>>8
    b[16+slot*544:16+(slot+1)*544]=s;slot+=1
src.write_bytes(bytes(b))
(app/'user-bank.js').write_text('"use strict";\nwindow.FZ_USER_BANK = '+json.dumps({'source':'Gills SD_CARD_PERF38H/USER_FZ.BIN + FZED page presets','slots':100,'used':slot,
  'sha256':hashlib.sha256(bytes(b)).hexdigest(),'base64':base64.b64encode(bytes(b)).decode()})+';\n')
print('presets',slot)
