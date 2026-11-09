"""Extract Core110 FZ labels, value formatting, held steps and exact CC sequences for the editor (PERF40N)."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
import os
GILLS = Path(os.environ.get('GILLS', str(ROOT.parent / 'Gills')))
APP = ROOT / 'outputs/FZED'
CORE = GILLS / 'outputs/Gills_Controller_Core_110.axp'
HEADER = GILLS / 'outputs/gills_core110/gills_shared.h'
tree = ET.parse(CORE)
objects = {p.get('name'):p.find('object') for p in tree.findall('.//patchobj')}
display = objects['OLED_PARAM_DISPLAY'].find('code.declaration').text
engine = objects['PAGE_SYSEX_ENGINE'].find('code.declaration').text


def strip_attributes(s):
    while '__attribute__' in s:
        a = s.index('__attribute__'); i = s.index('(',a); depth = 0
        for j in range(i,len(s)):
            depth += (s[j]=='(')-(s[j]==')')
            if depth == 0:
                s = s[:a]+s[j+1:]; break
    return s


def function(signature):
    a = engine.index(signature); b = engine.index('{',a); depth = 0
    for i in range(b,len(engine)):
        depth += (engine[i]=='{')-(engine[i]=='}')
        if depth == 0:
            return engine[a:i+1]
    raise ValueError(signature)


source = r'''
#include <cstdio>
#include <cstring>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <iomanip>
#include <vector>
#define __USAT(x,b) ((int)(x)<0?0:((int)(x)>((1<<(b))-1)?((1<<(b))-1):(int)(x)))
''' + HEADER.read_text() + '\nstruct Display {\n' + display + r'''
};
int fzEnvStep=1,fzCtrl=0,gMidiOut=0;
std::vector<std::pair<int,int>> sent;
void fzSendCc(int cc,int value){sent.push_back({cc,value});}
void fzInitReset(){}
''' + function('int fzParamId(') + '\n' + function('void fzSendCode(') + r'''
static int skipCode(int c){return c==1280||c==1281||c==1283||c==1284||c==1285||c==1286||c==1287;}  /* Gills-only, or editor commands */
static int sliceN(int c){return c==379?48:(c==380||c==381)?37:0;}
static int wireOf(int code,int raw){if(sliceN(code))return (raw*sliceN(code))>>7;return code<128?fzValue(code,raw):raw;}
void emit(const char *group,int page,int variant,int stage,int ctrl,int fx,int cap){
 Display d{};d.fzFx=fx;d.fzCap=cap;fzEnvStep=stage;fzCtrl=ctrl;gFzFxMode=fx;
 gSel[4][10]=(cap==2);fzSetView(cap?10:9);
 for(int pot=0;pot<10;pot++){
  int code=fzCode(page,pot);if(code<0||skipCode(code))continue;
  char label[160];d.fzLabel(label,code,stage,ctrl);
  std::cout<<"{\"group\":"<<std::quoted(group)<<",\"page\":"<<page<<",\"variant\":"<<variant
   <<",\"slot\":"<<pot<<",\"code\":"<<code<<",\"label\":"<<std::quoted(label)<<",\"values\":[";
  for(int raw=0;raw<128;raw++){
   char text[160];int value=wireOf(code,raw);
   if(code==111)strcpy(text,fzWaveName(value));else d.fzCodeText(text,code,value,-1,-1,-1);
   if(raw)std::cout<<",";std::cout<<std::quoted(text);
  }
  std::cout<<"]";
  if(code==89){
   std::cout<<",\"clockValues\":[";
   for(int raw=0;raw<128;raw++){char text[160];d.fzCodeText(text,code,raw,127,-1,-1);if(raw)std::cout<<",";std::cout<<std::quoted(text);}
   std::cout<<"]";
  }
  if(code==114||(code==103&&cap==0)){
   std::cout<<",\"rateValues\":[";
   for(int rate=0;rate<4;rate++){
    if(rate)std::cout<<",";std::cout<<"[";
    for(int raw=0;raw<128;raw++){char text[160];d.fzCodeText(text,code,raw,-1,rate,rate);if(raw)std::cout<<",";std::cout<<std::quoted(text);}
    std::cout<<"]";
   }
   std::cout<<"]";
  }
  std::cout<<",\"wireValues\":[";
  for(int raw=0;raw<128;raw++){if(raw)std::cout<<",";std::cout<<wireOf(code,raw);}
  {int N=sliceN(code)?sliceN(code):potSteps(4,page,pot);std::cout<<"],\"steps\":[";
   for(int n=0;n<N;n++){if(n)std::cout<<",";std::cout<<(sliceN(code)?(n*128+64)/N:stepRaw(4,page,pot,n,N));}}
  sent.clear();fzSendCode(code,wireOf(code,127));auto hi=sent;   // a value that differs between two settings is the setting
  sent.clear();fzSendCode(code,wireOf(code,0));
  std::cout<<"],\"sequence\":[";
  for(size_t i=0;i<sent.size();i++){
   if(i)std::cout<<",";std::cout<<"["<<sent[i].first<<",";
   if(i+1==sent.size()||(hi.size()==sent.size()&&hi[i].second!=sent[i].second))std::cout<<"null";else std::cout<<sent[i].second;
   std::cout<<"]";
  }
  std::cout<<"]}"<<std::endl;
 }
}
int main(){
 emit("voice",0,0,1,0,-1,0);emit("adsr",1,0,1,0,-1,0);
 for(int step=1;step<=8;step++)emit("envelope",2,step,step,0,-1,0);
 emit("lfo1",3,0,1,0,-1,0);emit("lfo2",4,0,1,0,-1,0);
 emit("velocity",5,0,1,0,-1,0);
 for(int ctrl=0;ctrl<3;ctrl++)emit("controllers",6,ctrl,1,ctrl,-1,0);
 for(int view=0;view<3;view++)emit("matrix",7+view,view,1,0,-1,0);
 emit("loop",10,0,1,0,-1,0);
 emit("record",11,0,1,0,-1,0);emit("capture",11,1,1,0,-1,1);
 emit("chop",12,0,1,0,-1,0);emit("capture2",12,2,1,0,-1,2);
 emit("slices",14,0,1,0,-1,0);emit("stretch",15,0,1,0,-1,0);
 for(int fx=-1;fx<15;fx++)emit("fx",13,fx,1,0,fx,0);
}
'''
source = strip_attributes(source)
with tempfile.TemporaryDirectory(prefix='fz_editor_profile_',dir='/tmp') as temp:
    exe = Path(temp)/'profile'
    build = subprocess.run(['clang++','-std=c++14','-O1','-Wno-pragma-once-outside-header',
        '-x','c++','-','-o',str(exe)],input=source,text=True,capture_output=True)
    assert build.returncode==0,build.stderr
    result = subprocess.run([str(exe)],text=True,capture_output=True,check=True)
    controls = [json.loads(line) for line in result.stdout.splitlines()]
    for control in controls:
        assert len(control['values'])==len(control['wireValues'])==128
        assert control['sequence'] and control['sequence'][-1][1] is None, control['code']
    def synth(group,slot,code,label,seq,texts,steps=()):
        # PERF commands the Gills makes with an encoder press or a second step (no pot of their own)
        return {'group':group,'page':-1,'variant':0,'slot':slot,'code':code,'label':label,'values':texts,
                'wireValues':list(range(128)),'steps':list(steps),'sequence':seq,'synthetic':True}
    mux=lambda k:[[10,88],[11,k],[10,89],[11,None]]
    band=lambda names:[names[min(len(names)-1,(r*len(names))>>7)] for r in range(128)]
    controls += [
        synth('bank',20,16,'NEW VOICE',[[16,None]],['REARM' if r<64 else ('WAIT' if r<120 else 'NEW VOICE') for r in range(128)]),
        synth('bank',21,1548,'VOICE SELECT',mux(12),['SELECT PICKED VOICE']*128),
        synth('record',9,1549,'EXIT FZED',mux(13),['DISCARD (ESC)' if r<64 else 'KEEP (ENTER)' for r in range(128)]),
        synth('chop',8,1550,'CHOP INTO',mux(6),['OWN BANK' if r<64 else 'TARGET BANK' for r in range(128)],(32,96)),
        synth('chop',10,1551,'FREEZE CHOP',mux(15),['FREEZE']*128),
    ]
    for control in controls:   # the FX filter's cutoff / resonance are plain 0-127 settings (the Gills shows its tape dB scale there)
        if control['group']=='fx' and control['variant']==8 and control['slot'] in (3,4):
            name='CUTOFF' if control['slot']==3 else 'RESONANCE'
            control['values']=[f'{name} {control["wireValues"][r]:03d}' for r in range(128)]
    profile = {'format':'fz-core110-profile-v1','target':'FZED','hardwareVerified':False,
        'firmwareSourceSHA256':hashlib.sha256(next(p for p in (ROOT/'outputs/FZ1_FZED.asm',ROOT/'outputs/FZ1_FZED40N.asm') if p.exists()).read_bytes()).hexdigest(),
        'sourceCore':'Core110','coreSHA256':hashlib.sha256(CORE.read_bytes()).hexdigest(),
        'headerSHA256':hashlib.sha256(HEADER.read_bytes()).hexdigest(),
        'controls':controls}
    APP.mkdir(parents=True,exist_ok=True)
    (APP/'profile.js').write_text('"use strict";\nwindow.FZ_PROFILE = '+json.dumps(profile,separators=(',',':'))+';\n')
    print(json.dumps({'controls':len(controls),'raw_value_checks':len(controls)*128,
                      'sourceCoreSHA256':profile['coreSHA256']}))
