"use strict";
(() => {
const $ = id => document.getElementById(id);
const profile = window.FZ_PROFILE;
const groups = [
 ['voice','Filter / Keys'],['adsr','ADSR'],['envelope','Envelope stages'],['lfo1','LFO 1'],['lfo2','LFO 2'],['velocity','Key / Velocity'],['controllers','Controllers'],['matrix','Mod matrix'],['loop','Play / Loop'],['stretch','Stretch'],['record','Record'],['capture','Capture'],['chop','Chop / Pattern'],['slices','Slices'],['fx','FX'],['bank','Bank builder'],['user','User presets']
];
const bankCodes=[[1547,'voice'],[1548,'bank'],[16,'bank'],[382,'slices'],[14,'voice'],[15,'voice'],[1550,'chop'],[1551,'chop']];  // the Bank builder page, in build order
const bankOnly=new Set([1547,14,15]);
const pageDescriptions = {
 voice:'Filter, tape speed and the voice’s key range. Choosing, adding and playing banks is on Bank builder.',
 stretch:'Stretch cuts the play range into 2-8 segments, one FZ loop each. Each segment holds for its loop time (about 19.8 ms a step) plus roughly one and a half grain passes, then moves on. TRACE plays on to a later loop, SKIP jumps; a loop earlier in the sample is always a jump. CUT LEAD-IN starts the note at the first loop (for Reverse and Shuffle). Off puts the voice’s own loops (and start) back.',
 slices:'The slices of the last chop: choose a slice, move it to another key, set its lowest / highest key in semitones and its output. Filter / env / LFO1 chooses whether edits go to every slice or the chosen one. Copy voice makes a copy sharing the same sample memory.',
 bank:'Build a bank of sounds without leaving the optional software. The steps below run top to bottom; the MIDI channel chosen in CH (top bar) is the channel each voice is added on.',
 adsr:'A simplified envelope for shaping amplifier and filter attack, decay, sustain, and release. Use Envelope stages for the full eight-stage FZ envelope.',
 velocity:'Set signed key-follow and velocity response. Zero is neutral; negative and positive values act in opposite directions.',
 capture:'Alternating record & playback: record a sample for the set duration, then automatically replay notes or chords using the selected rate, hold, intervals, and release behavior. (FZ is silent during recording).',
 lfo2:'LFO 2 can modulate a direct destination and a second Mod Matrix destination. Warble attempts to emulate tape warble. Set Mode to MIDI Clock to use clock divisions; otherwise Rate / Division sets free-running speed.',
 record:'Norm Filter at RATE CUT follows the recording rate: 36 kHz has no anti-aliasing filter; 18, 9, and 4.5 kHz use an appropriate filter slope. Override the cutoff to retain filtering with a higher cutoff and more grit.',
 chop:'Chop divides a sample into slices. Pattern is a rhythmic sequence of steps that can trigger or modulate sound; select a pattern, set its rate (free ms/step or MIDI-clock division), and route it where wanted in the Mod Matrix.',
 fx:'P1 selects the effect, P6 sets dry/wet, and P10 renders. Pockey2 is render-only; TapeHack > Pockey2 runs only its TapeHack stage live. Filter is mainly for Render. CC94 matrix routings are audible only with Ring Mod, Karplus-Strong, or Filter.'
};
const STORAGE = 'fz-perf38x-editor-v1';
const fxOrder = [1,5,14,9,10,3,11,12,13,4,7,6,8,2,0];
const fxUsedSlots={1:[0,3,4,5,6,9],5:[0,3,4,5,6,9],14:[0,3,4,5,6,9],9:[0,3,4,5,6,9],10:[0,3,5,6,9],3:[0,1,2,5,6,9],11:[0,3,4,5,6,9],12:[0,2,3,4,5,6,9],13:[0,3,4,5,6,9],4:[0,3,4,5,6,9],7:[0,3,4,5,6,9],6:[0,3,4,5,6,9],8:[0,2,3,4,5,6,9],2:[0,1,2,3,4,5,6,9],0:[0,1,2,5,6,9]};
const actionCodes = new Set([15,16,98,100,101,106,107,108,109,118,263,382,1548,1549,1551]);
const mux=(k,v)=>[[10,88],[11,k],[10,89],[11,v]];
function commandPackets(d,raw){  // the exact messages for a command (re-arm first where the FZ needs a rising edge)
 if(d.code===108&&d.group==='capture')return raw>=64?mux(7,127):[[108,0]];  // capture on is a PERF control since PERF40K
 if(d.code===1549)return raw===0?mux(13,0):[...mux(14,raw===1?0:raw===2?64:127),...mux(13,127)];
 if(d.code===1548||d.code===1551)return encode(d,127);
 const packets=encode(d,raw);
 if([16,100,101,106,107,109,118,263,382].includes(d.code))packets.unshift(...encode(d,0));
  if(d.code===15&&raw!==64)packets.unshift(...encode(d,64));
 return packets;
}
const state = {values:{}, mappings:{}, group:'voice', variants:{envelope:1,controllers:0,matrix:0,capture:1,fx:-1}, channel:0};
let access=null, armed=false, learning=null, midiActionsEnabled=false, queue=[], timer=null, octave=3, dialogResolve=null;
const actionEdges=new Map();
let pageFollowTimer=null,lastFollowPageAt=-Infinity,pendingFollowDescriptor=null;
const followPairs=new Map();
const held = new Map(), noteEndpoints = new Map();
let userBank=null;
function status(text){$('status').textContent=text;}
function icons(){window.lucide?.createIcons();}
function node(tag, attrs={}, text){const el=document.createElement(tag);for(const [key,value] of Object.entries(attrs)){if(key==='class')el.className=value;else el.setAttribute(key,String(value));}if(text!==undefined)el.textContent=text;return el;}
function button(text,icon,handler,title=text){const b=node('button',{type:'button',title});if(icon)b.append(node('i',{'data-lucide':icon}));b.append(document.createTextNode(text));b.onclick=handler;return b;}
function current(){if(state.group==='capture'){const primary=profile.controls.filter(d=>d.group==='capture'&&d.variant===1&&d.code!==110);const ordered=[...primary.filter(d=>d.code===108||d.code===109),...primary.filter(d=>d.code!==108&&d.code!==109)];return [...ordered,...profile.controls.filter(d=>d.group==='capture2'&&d.variant===2&&(d.slot<4||d.code===41)).map(d=>({...d,sourceSlot:d.slot,slot:d.code===41?14:d.slot+10}))];}if(state.group==='fx'){const raw=state.values['cc:112'];const variant=raw===undefined?1:fxVariant(raw);return profile.controls.filter(d=>d.group==='fx'&&d.variant===variant&&d.code!==100&&d.code!==101&&fxUsedSlots[d.variant]?.includes(d.slot));}if(state.group==='bank')return bankCodes.map(([code,group],i)=>{const d=profile.controls.find(c=>c.code===code&&c.group===group);return d?{...d,sourceSlot:d.slot,slot:i}:null;}).filter(Boolean);
 return profile.controls.filter(d=>d.group===state.group&&d.variant===(state.variants[state.group]??0)&&d.code!==1280&&!(state.group==='voice'&&bankOnly.has(d.code))).map(d=>d.code===71?{...d,label:'TAPE SPEED'}:d);}
function key(d){if(d.code===111)return 'cc:111';if(d.code===1024)return 'param:119';if(d.code===110)return 'cc:110';if(d.group==='capture'||d.group==='capture2')return `${d.group}:${d.code}`;if(d.group==='fx'&&[113,114,115,116,94,95,117,119].includes(d.code))return `fx:${d.variant}:${d.code}`;if(d.sequence.length===2&&d.sequence[0][0]===10)return `param:${d.sequence[0][1]}`;return `cc:${d.code}`;}
function mapKey(d,actionRaw=null){const base=`${d.group}:${d.sourceSlot??d.slot}`;return actionRaw===null?base:`${base}:action:${actionRaw}`;}
function isAction(d){return actionCodes.has(d.code);}
function encode(d,raw){if(!Number.isInteger(raw)||raw<0||raw>127)throw Error('Invalid MIDI value');return d.sequence.map(([cc,value])=>[cc,value===null?d.wireValues[raw]:value]);}
const validKeys=new Set(profile.controls.map(key));
const validMapKeys=new Set(profile.controls.flatMap(d=>isAction(d)?actionOptions(d).map(([raw])=>mapKey(d,raw)):[mapKey(d)]));
function validate(data){
 if(!data||data.format!==STORAGE||!data.values||typeof data.values!=='object'||Array.isArray(data.values))throw Error('Not a FZED settings file');
 const values={},mappings={};
 const moved=data.layout===110?null:{"voice":{"4":5,"5":7,"7":4},"envelope":{"2":5,"3":6,"5":2,"6":3},"lfo1":{"2":5,"3":6,"4":7,"5":8,"6":2,"7":3,"8":4},"lfo2":{"1":6,"2":1,"3":5,"5":2,"6":3},"velocity":{"0":4,"1":5,"2":6,"3":7,"4":8,"5":0,"6":1,"7":2,"8":3},"controllers":{"4":6,"5":7,"6":8,"7":4,"8":9,"9":5},"loop":{"2":5,"3":6,"4":7,"5":8,"6":2,"7":3,"8":4},"record":{"4":5,"5":6,"6":7,"7":8,"8":4}};  // Core 110 moved pots: carry older Learn assignments to the same control
 const remap=k=>{if(!moved)return k;const p=k.split(':');const t=moved[p[0]]?.[p[1]];if(t===undefined)return k;p[1]=String(t);return p.join(':');};
 for(const [k,v] of Object.entries(data.values)){if(!validKeys.has(k)||!Number.isInteger(v)||v<0||v>127)throw Error('Invalid parameter value');values[k]=v;}
 for(const [k,m] of Object.entries(data.mappings??{})){if(!validMapKeys.has(remap(k))||!m||typeof m.input!=='string'||m.input.length>300||!Number.isInteger(m.channel)||m.channel<0||m.channel>15||!Number.isInteger(m.cc)||m.cc<0||m.cc>119)throw Error('Invalid MIDI Learn mapping');mappings[remap(k)]={input:m.input,channel:m.channel,cc:m.cc};}
 return {values,mappings};
}
function save(){try{localStorage.setItem(STORAGE,JSON.stringify({format:STORAGE,layout:110,values:state.values,mappings:state.mappings}));}catch{status('Settings storage unavailable');}}
try{const data=localStorage.getItem(STORAGE);if(data)Object.assign(state,validate(JSON.parse(data)));}catch{status('Stored settings ignored: invalid format');}
function output(){return access?.outputs.get($('outputPort').value);}
function cancelQueue(){queue=[];if(timer!==null)clearTimeout(timer);timer=null;}
// ---- Expected FZ screen: what FZED shows for the messages the editor sends or receives (16 x 8 characters),
// worked out from the messages, not read back from the FZ (see fzEcho for the line layout).
const fzLines=['FZED','','','','','','',''],fzSt={psel:0,mux:null,rate:0,len:4,gain:0,trig:64,state:'IDLE ',fx:1,live:false,cap:null};
const fzFxNames=['TAPEHACK','WAVEFOLDER','XOVER FUZZ','RECTIFIER','DECIMATOR','LINEAR CRUSH','BIT MANGLE','ECHO / COMB','POSITION','RING MOD','TUBE2','KARPLUS-STRG','FILTER','TAPE>POCKEY','POCKEY2'];
const d3=n=>String(Math.max(0,Math.min(999,n))).padStart(3,'0');
function fzLine(i,text){fzLines[i]=String(text).slice(0,16);}
function fzRecord(){
 const rate=['36K','18K','9K','4.5K'][Math.min(3,fzSt.rate>>5)],secs=(fzSt.len+1)*0.1*[1,2,4,8][Math.min(3,fzSt.rate>>5)];
 fzLine(5,`REC ${rate.padEnd(4)} ${secs.toFixed(1).padStart(5,'0')}S`);
 fzLine(6,`${fzSt.state}${(fzSt.gain>=64?'-20DB':'0DB').padStart(6)} T${d3(fzSt.trig)}`);
}
// FZ SCREEN: what FZED draws, as its emulator shows. Line 3 is FZED's message line, line 4 its C=ccc vvv / P=ppp vvv echo
// (FZED leaves the echo out when a control's message is a paced one: FX values, capture and chord settings). Lines 5-6: record.
const fzFxMode=[1,5,14,9,10,3,11,12,13,4,7,6,8,2,0],fzFxBy=['POCKEY2','TAPEHACK','TAPE>POCKEY','LINEAR CRUSH','RING MOD','WAVEFOLDER','KARPLUS-STRG','TUBE2','FILTER','RECTIFIER','DECIMATOR','BIT MANGLE','ECHO / COMB','POSITION','XOVER FUZZ'];
const fzRingT=[3,3,4,4,4,5,5,5,6,6,7,7,8,8,9,10,10,11,12,13,14,15,16,17,18,20,21,23,25,27,29,31,33,36,38,41,44,48,51,55,59,64,69,74,79,85,92,99,106,114,123,132,142,153,165,177,190,205,220,237,255,274,295,317,341,367,395,425,457,492,529,569,612,658,708,762,819,881,948,1020,1097,1180,1269,1365,1469,1580,1699,1828,1966,2115,2275,2447,2633,2832,3046,3277,3525,3792,4079,4387,4719,5077,5461,5874,6319,6797,7312,7865,8460,9101,9789,10530,11328,12185,13107,14099,15166,16314,17549,18878,20306,21843,23497,25275,27188,29246,31460,33841];
const fzCapMs=[10,20,30,50,75,100,150,200,300,500,750,1000,1500,2000,3000,4000],fzHold='x1x2x4x82s4s8sRC',fzSync='FSEQH124',fzChord='ORIGOCTS5+8 MAJ MIN MAJ7MIN75-8-WIDE',fzVel='SAMRNDFALRIS';
const fzStag=[0,1,2,3,4,6,8,10,15,20,25,30,40,60,90,120],fzFade=[0,1,2,4,8,16,24,32];
const pct=v=>Math.floor(v*100/127);
function fzCapLine(){const c=fzSt.cap;return `C${String(fzCapMs[c.len]).padStart(4,'0')} ${fzHold.substr(c.hold*2,2)} ${c.tr<0?'-':'+'}${String(Math.abs(c.tr)).padStart(2,'0')} ${fzSync[c.sync]}`;}
function fzChordLine(){const c=fzSt.cap;return `${fzChord.substr(c.cch*4,4)} ${fzVel.substr(c.cvm*3,3)} ${String(fzStag[c.csg]*20).padStart(4,'0')}MS`;}
function fzEcho(cc,v){
 let echo=true;const msg=t=>fzLine(3,t.padEnd(15)),quiet=t=>{msg(t);echo=false;},cap=fzSt.cap;
 if(cc===10)fzSt.psel=v;
 else if(cc===11){
  const p=fzSt.psel;
  if(p===88)fzSt.mux=v;
  else if(p===89&&fzSt.mux===6)msg(v>=64?'CHOP INTO TARGET':'CHOP INTO: OWN  ');
  else if(p===89&&fzSt.mux===7&&v>=64&&!cap){fzSt.cap={len:Math.min(15,fzSt.len>>3),hold:Math.min(7,fzSt.trig>>5),tr:0,sync:0,cch:0,cvm:0,csg:0,fad:0};quiet(fzCapLine());}
  else if(p===89&&fzSt.mux===10&&v>=64)msg('SLICES: OWN F/E');
  else if(p===89&&fzSt.mux===15&&v>=64)msg('CHOP FROZEN');
  else if(p===121)msg(v<15?'OUTPUT OFF':`OUTPUT ${Math.floor(v*9/128)}`);
  else if(p===7&&v>=120)msg('VOICE INIT: ALL');
 }
 else if(cap&&[102,103,105,23,33].includes(cc)){
  if(cc===103)cap.len=v>>3;else if(cc===105){cap.hold=v>>4;fzSt.trig=Math.min(254,v*2);}else if(cc===23)cap.tr=((v*49*2)>>8)-24;else if(cc===33)cap.sync=v>>4;
  else if(cc===102)fzSt.rate=v;
  quiet(fzCapLine());}
 else if(cap&&[96,97,99].includes(cc)){if(cc===96)cap.cch=(v*9*2)>>8;else if(cc===97)cap.cvm=v>>5;else cap.csg=v>>3;quiet(fzChordLine());}
 else if(cap&&(cc===34||cc===98)){cap.fad=v>>4;quiet(`FADE ${String(fzFade[cap.fad]*50).padStart(4,'0')}MS`);}
 else if(cap&&cc===108&&v<64){fzSt.cap=null;msg('CAPTURE OFF');}
 else if(cap&&[104,109,110,41].includes(cc)){if(cc===104){fzSt.gain=v;}}
 else if(cc===97)msg('CHOP '+['EVEN','EVEN+ZERO','TRANSIENT'][Math.min(2,Math.floor(v*3/128))]);
 else if(cc===99)msg(`CHOP ${String(4<<(v>>5)).padStart(2,'0')} SLICES`);
 else if(cc===98)msg(v>=120?'CHOPPING...':v>=64?'> PLAY SLICES':'> PLAY VOICE');  // '>' lines are the editor's note of what CC98 asked for
 else if(cc===86)quiet(v<43?'ONE-SHOT':v<85?'ORIGINAL':'LOOP');   // loop mode, named by FZED
 else if(cc===70)quiet(['ORIGINAL','REVERSE','CUE','CUE'][v>>5]);   // play mode
 else if(cc===112){fzSt.fx=fzFxMode[Math.min(14,(v*15)>>7)];quiet('FX '+fzFxBy[fzSt.fx]);}
 else if(cc===113)quiet(`BITS ${String(fzSt.fx===3?2+Math.floor(14*v*v/16129):((v*13)>>7)+4).padStart(2,'0')}`);
 else if(cc===114)quiet(`DEFREQ ${d3(v)}`);
 else if(cc===115){const n=d3(pct(v));quiet(fzSt.fx===7?`TUBE PAD ${n}%`:`INPUT x${n.slice(0,2)}.${n[2]}`);}
 else if(cc===116)quiet(fzSt.fx===7?`TUBE AMT ${d3(pct(v))}%`:`OUTPUT ${d3(pct(v))}%`);
 else if(cc===117)quiet(`MIX ${d3(pct(v))}%`);
 else if(cc===94){if(fzSt.fx===6)quiet(`KS NOTE ${d3(v)}`);else{const n=String(Math.floor(fzRingT[v]*10/16)).padStart(5,'0');quiet(`RING ${n.slice(0,4)}.${n[4]}HZ`);}}
 else if(cc===95)quiet(fzSt.fx===6?`KS FDBK ${d3(pct(v))}%`:v>=64?'RING SQUARE':'RING SINE');
 else if(cc===119){if(v>=64){msg(fzSt.fx===0?'LIVE: NO POCKEY':'LIVE FX ON');fzSt.live=fzSt.fx!==0;}else if(fzSt.live){fzSt.live=false;msg('LIVE FX OFF');}}
 else if(cc===14){quiet(v<15?'VOICE MODE':`BANK ${Math.floor(v*9/128)}`);}
 else if(cc===15){if(v<32)quiet('VOICE ADDED');else if(v>=96)quiet(`CH${String(state.channel+1).padStart(2,'0')} CLEARED`);else return drawFz();}  // 32-95 re-arms quietly
 else if(cc===111||cc===9)echo=false;   // preset wave: FZED draws no echo for these
 else if(cc===102){fzSt.rate=v;fzRecord();}
 else if(cc===103){fzSt.len=v;fzRecord();}
 else if(cc===104){fzSt.gain=v;fzRecord();}
 else if(cc===105){fzSt.trig=Math.min(254,v*2);fzRecord();}
 else if(cc===110)fzRecord();
 else if([106,107,108,109].includes(cc)&&v>=64){if(cc===108&&fzSt.state==='IDLE ')msg('NOT ARMED');else{fzSt.state={106:'ARMED',107:'REC  ',108:'WAIT ',109:'DONE '}[cc];fzRecord();}}
 else if(cc===120||cc===123)return;
 if(echo)fzLine(4,cc===11?`P=${d3(fzSt.psel)} ${d3(v)}`:`C=${d3(cc)} ${d3(v)}`);
 drawFz();
}
function drawFz(){const el=$('fzLcd');if(el)el.textContent=fzLines.map(l=>l.padEnd(16)).join('\n');}
function fzObserve(m){if(m&&m.length>=3&&(m[0]&0xf0)===0xb0)fzEcho(m[1],m[2]);}
function sendNow(port,channel,packets){if(!port||port.state==='disconnected')return false;try{for(const packet of packets){const m=[packet[0]|channel,...packet.slice(1)];port.send(m);monitorLog(m,'OUT');}return true;}catch{held.clear();noteEndpoints.clear();status('MIDI send failed; output locked');setArmed(false);return false;}}
function drain(){timer=null;if(!armed||!output()){cancelQueue();return;}const job=queue.shift();if(job){sendNow(job.port,job.channel,job.packets);$('activity').textContent=job.label;}
 if(queue.length)timer=setTimeout(drain,job?.pace??8);
}
function enqueue(packets,label,id=null,pace=8){for(const [cc,v] of packets)fzEcho(cc,v);  // the FZ screen follows every change, output enabled or not
 if(!armed||!output()){status('Output locked · change stored locally');return false;}
 const job={packets:packets.map(([cc,v])=>[0xb0,cc,v]),label,id,pace,port:output(),channel:state.channel};
 if(id!==null){const old=queue.findIndex(x=>x.id===id);if(old>=0)queue[old]=job;else queue.push(job);}else queue.push(job);
 if(queue.length>256){cancelQueue();status('MIDI queue cleared: too many commands');return false;}
 if(timer===null)timer=setTimeout(drain,0);return true;
}
function rememberEndpoint(port,channel){if(port)noteEndpoints.set(port.id+':'+channel,{port,channel});}
function releaseNotes(){for(const h of held.values())sendNow(h.port,h.channel,[[0x80,h.note,0]]);held.clear();for(const h of noteEndpoints.values())sendNow(h.port,h.channel,[[0xb0,64,0]]);noteEndpoints.clear();document.querySelectorAll('.held').forEach(k=>k.classList.remove('held'));}
function setArmed(value){if(!value){cancelQueue();releaseNotes();}armed=!!value;$('arm').setAttribute('aria-pressed',String(armed));$('arm').replaceChildren(node('i',{'data-lucide':armed?'unlock':'lock'}),document.createTextNode(armed?'Output enabled':'Output locked'));icons();}
function endpointChange(){setArmed(false);status('Endpoint changed · output locked');}
function panic(){cancelQueue();releaseNotes();if(sendNow(output(),state.channel,[[0xb0,64,0],[0xb0,120,0],[0xb0,123,0]]))status('Panic sent · sustain off / CC120 / CC123');else status('No MIDI output available');}
function human(d,raw){
 if(raw===undefined)return '—';
 if(d.clockValues&&state.values['cc:93']>=86)return d.clockValues[raw];
 if(d.code===89&&state.values['cc:93']<86)return `FREE RATE ${raw}`;
 if(d.rateValues){const rate=state.values[d.code===103?'cc:102':'cc:71'];if(rate!==undefined)return d.rateValues[Math.min(3,rate>>5)][raw];}
 const text=d.values[raw]||String(d.wireValues[raw]);
 return /^CC\d+ VAL /.test(text)?String(Number(text.replace(/^CC\d+ VAL /,''))):text;
}
function signedKind(d){if(d.group==='velocity'&&d.label!=='VEL > RES')return 127;if(d.group==='matrix'&&state.variants.matrix===1)return 64;return 0;}
function isSignedControl(d){return signedKind(d)>0;}
function signedValue(d,raw){const limit=signedKind(d);return raw===64?0:raw<64?Math.round((raw-64)*limit/64):Math.round((raw-64)*limit/63);}
function rawForSigned(d,value){const limit=signedKind(d);if(value===0)return 64;return value<0?Math.round(64+value*64/limit):Math.round(64+value*63/limit);}
function change(d,raw,send=true){state.values[key(d)]=raw;if(d.code===1024)state.values['param:99']=32;save();if(send)enqueue(encode(d,raw),`${d.label} · ${human(d,raw)}`,key(d));if(d.code===112){state.variants.fx=fxVariant(raw);render();}else if(d.code===93||d.code===265||d.code===1536||d.code===99)render();else updateControls();}
function captureIsOn(){return (state.values['capture:108']??0)>=64;}
function descriptorPage(d){
 if(d.group==='voice'&&bankOnly.has(d.code))return 'bank';
 if(d.group==='capture2'&&d.code>=264&&d.code<=343)return 'chop';
 return d.group==='capture2'?'capture':d.group;
}
function followPage(d){
 if(!$('followPages').checked)return;
 pendingFollowDescriptor=d;
 const now=performance.now(),delay=Math.max(0,300-(now-lastFollowPageAt));
 if(pageFollowTimer!==null)return;
 pageFollowTimer=setTimeout(()=>{
  pageFollowTimer=null;const target=pendingFollowDescriptor;pendingFollowDescriptor=null;
  if(!$('followPages').checked||!target)return;
  lastFollowPageAt=performance.now();let changed=state.group!==descriptorPage(target);state.group=descriptorPage(target);
  if(target.group==='envelope'&&state.variants.envelope!==target.variant){state.variants.envelope=target.variant;changed=true;}
  if((target.group==='controllers'||target.group==='matrix')&&state.variants[target.group]!==target.variant){state.variants[target.group]=target.variant;changed=true;}
  if(target.group==='fx'&&target.code!==112&&state.variants.fx!==target.variant){state.variants.fx=target.variant;changed=true;}
  if(changed)render();
 },delay);
}
function descriptorRaw(d,wire){
 let raw=d.wireValues.indexOf(wire);if(raw>=0)return raw;
 let distance=Infinity;for(let i=0;i<d.wireValues.length;i++){const next=Math.abs(d.wireValues[i]-wire);if(next<distance){distance=next;raw=i;}}
 return raw;
}
// Incoming values: FZED-aware controllers send the FZED wire value (e.g. 0-5 for the LFO 1 waveform); a plain
// controller sends 0-127 across the whole travel. INPUT VALUES chooses which, so both land on the right setting.
function plainInput(){return $('inputValues')?.value==='plain';}
function directCc(d){return d.sequence.length===1&&d.sequence[0][1]===null?d.sequence[0][0]:null;}
function incomingRaw(d,value,cc=directCc(d)){
 // a learned CC that is not the control's own FZED CC is a plain knob; the control's own CC carries FZED values
 if(plainInput()||cc!==directCc(d))return value;
 return descriptorRaw(d,value);
}
function applyFollowDescriptors(descriptors,wire,plain=false){
 const usable=descriptors.filter(d=>(!isAction(d)||d.code===108)&&d.code!==1280);
 if(!usable.length)return null;
 const preferred=usable.find(d=>descriptorPage(d)===state.group)??usable[0];
 for(const d of usable){const raw=plain?wire:descriptorRaw(d,wire);if(raw>=0)change(d,raw,false);}
 followPage(preferred);
 return preferred;
}
function resolvePlainCc(cc,value){
 let candidates;
 if(cc===112){
  const source=profile.controls.find(d=>d.group==='fx'&&d.code===112&&d.slot===0);
  if(!source)return [];
  const raw=plainInput()?value:descriptorRaw(source,value);
  return raw<0?[]:[{...source,variant:fxVariant(raw)}];
 }else if(cc===110){
  candidates=profile.controls.filter(d=>d.group==='record'&&d.code===110);
 }else if([94,95,115,116].includes(cc)){
  const raw=state.values['cc:112']??0,variant=fxVariant(raw);
  candidates=profile.controls.filter(d=>d.group==='fx'&&d.variant===variant&&d.code===cc&&fxUsedSlots[variant]?.includes(d.slot));
 }else if([96,97,99].includes(cc)){
  const group=captureIsOn()?'capture2':'chop';
  candidates=profile.controls.filter(d=>d.group===group&&d.code===cc);
 }else if((cc===23||cc===33)&&captureIsOn()){
  candidates=profile.controls.filter(d=>d.group==='capture'&&d.code===cc);
 }else{
  candidates=profile.controls.filter(d=>d.code===cc&&d.code<128&&d.group!=='capture2'&&d.group!=='fx');
 }
 return candidates.filter(d=>!isAction(d)||d.code===108);
}
function matchingParameter(id,kind='ordinary'){
 return profile.controls.filter(d=>{
  if(d.sequence.length<2||d.sequence[0][0]!==10||d.sequence[0][1]===null||d.sequence.at(-1)[0]!==11||d.sequence.at(-1)[1]!==null)return false;
  if(kind==='lfo-destination')return d.code===1024&&d.sequence.length===4;
  if(d.sequence[0][1]!==id)return false;
  return kind!=='ordinary'||d.sequence.length===2;
 });
}
function followParameter(input,ch,cc,value){
 const id=`${input.id}:${ch}`;let context=followPairs.get(id);
 if(!context){context={param:null,pendingSource10:null,pendingSourceTimer:null,lfoDestination:false};followPairs.set(id,context);}
 if(cc===10){
  if(context.pendingSource10){
   clearTimeout(context.pendingSourceTimer);context.pendingSourceTimer=null;
   if(value===119)context.lfoDestination=true;
   else{applyFollowDescriptors(matchingParameter(99),context.pendingSource10);context.lfoDestination=false;}
   context.pendingSource10=null;
  }
  context.param=value;return;
 }
 if(cc!==11||context.param===null)return;
 if(context.pendingSource10!==null){clearTimeout(context.pendingSourceTimer);context.pendingSourceTimer=null;applyFollowDescriptors(matchingParameter(99),context.pendingSource10);context.pendingSource10=null;}
 const param=context.param;  // FZED keeps the CC10 choice per channel, so a bare CC11 still edits it
 if(param===88){context.mux=value;return;}  // PERF40F+: parameter 88 chooses a control, 89 sets it
 if(param===89){if(context.mux===undefined||context.mux===null)return;const k=context.mux;if(k===7){const cap=profile.controls.find(d=>d.group==='capture'&&d.code===108);if(cap&&value>=64){change(cap,127,false);followPage(cap);}return;}applyFollowDescriptors(profile.controls.filter(d=>!d.synthetic&&d.sequence.length===4&&d.sequence[0][1]===88&&d.sequence[1][1]===k),value);return;}
 if(param===99&&value===32){
  context.pendingSource10=value;
  context.pendingSourceTimer=setTimeout(()=>{if(context.pendingSource10===32){context.pendingSource10=null;context.pendingSourceTimer=null;applyFollowDescriptors(matchingParameter(99),32);}},35);
  return;
 }
 if(param===119&&context.lfoDestination){context.lfoDestination=false;applyFollowDescriptors(matchingParameter(119,'lfo-destination'),value);return;}
 context.lfoDestination=false;applyFollowDescriptors(matchingParameter(param),value);
}
function forwardIncoming(input,data){
 if(!$('outputPort').value||!armed||input.id===$('outputPort').value)return;
 const port=output();if(!port||port.state==='disconnected')return;
 try{port.send(Array.from(data));monitorLog(data,'OUT');fzObserve(data);$('activity').textContent='Follow · CC'+data[1];}
 catch{held.clear();noteEndpoints.clear();status('MIDI send failed; output locked');setArmed(false);}
}
function learnedDescriptor(input,ch,cc){
 for(const d of current()){
  if(isAction(d)){for(const [raw]of actionOptions(d)){const m=state.mappings[mapKey(d,raw)];if(m&&m.input===input.id&&m.channel===ch&&m.cc===cc)return {...d,learnRaw:raw};}}
  else{const m=state.mappings[mapKey(d)];if(m&&m.input===input.id&&m.channel===ch&&m.cc===cc)return d;}
 }
 for(const d of profile.controls){if(!isAction(d))continue;for(const [raw]of actionOptions(d)){const m=state.mappings[mapKey(d,raw)];if(m&&m.input===input.id&&m.channel===ch&&m.cc===cc)return {...d,learnRaw:raw};}}
 return null;
}
function triggerLearnedAction(d,input,ch,cc,value){
 const id=`${input.id}:${ch}:${cc}`;
 if(d.code===108&&d.group==='capture'){const next=value>=64,previous=actionEdges.get(id)??false;actionEdges.set(id,next);if(next!==previous&&midiActionsEnabled)enqueue(commandPackets(d,d.learnRaw??(next?127:0)),`${d.label} · ${next?'ON':'OFF'}`);return;}
 const high=value>=64,previous=actionEdges.get(id)??false;actionEdges.set(id,high);
 if(!high||previous)return;
 if(!midiActionsEnabled){status('MIDI action ignored · enable MIDI actions first');return;}
 const raw=d.learnRaw??actionOptions(d)[0]?.[0]??127,label=actionOptions(d).find(item=>item[0]===raw)?.[1]??d.label,packets=commandPackets(d,raw);
 if(d.code===98){sendCommand(d,raw,label);return;}
 enqueue(packets,label);
}
function followCc(input,ch,cc,value){
 if(ch!==state.channel)return null;
 if(cc===10||cc===11){if(!plainInput())followParameter(input,ch,cc,value);return null;}
 return applyFollowDescriptors(resolvePlainCc(cc,value),value,plainInput());
}
function updateControls(){for(const d of current()){const tile=document.querySelector(`[data-slot="${d.slot}"]`);if(!tile)continue;const raw=state.values[key(d)];tile.querySelector('output').textContent=d.code===108&&raw!==undefined?(raw>=64?'CAPTURE ON':'CAPTURE OFF'):isAction(d)?'Explicit command':isSignedControl(d)&&raw!==undefined?String(signedValue(d,raw)):human(d,raw);const range=tile.querySelector('input[type=range]');const number=tile.querySelector('input[type=number]');const select=tile.querySelector('select');const widget=tile.querySelector('.knob')??tile.querySelector('.switch');if(widget)widget.show(raw);const signed=isSignedControl(d);if(range)range.value=raw??64;if(number)number.value=signed&&raw!==undefined?signedValue(d,raw):raw??'';if(select&&raw!==undefined){const match=[...select.options].find(o=>Number(o.value)===raw&&o.value!=='')??[...select.options].find(o=>o.textContent===human(d,raw));select.value=match?.value??'';}}drawEnvelope();}
function confirmAction(title,text){if($('confirmation').open)return Promise.resolve(false);$('confirmTitle').textContent=title;$('confirmText').textContent=text;$('confirmation').showModal();return new Promise(resolve=>{dialogResolve=resolve;});}
$('confirmation').addEventListener('close',()=>{dialogResolve?.($('confirmation').returnValue==='confirm');dialogResolve=null;$('confirmation').returnValue='cancel';});
function actionOptions(d){
 if(d.code===15)return [[64,'Re-arm bank add'],[0,'Add this voice to bank'],[127,'Clear this MIDI channel']];
 if(d.code===16)return [[0,'Re-arm new voice'],[127,'Select next empty voice']];
 if(d.code===98)return [[127,'Create slices'],[64,'Play slices'],[0,'Return to voice']];
 if(d.code===108&&d.group==='capture')return [[0,'Leave capture'],[127,'Enter capture']];
 if(d.code===382)return [[127,'Copy voice']];
 if(d.code===1548)return [[127,'Select picked voice']];
 if(d.code===1549)return [[0,'Discard (ESC)'],[1,'Keep sound (ENTER)'],[2,'Keep all of edit voice (ENTER)'],[3,'Keep all (ENTER)']];
 if(d.code===1551)return [[127,'Freeze chop']];
 return [[127,d.label]];
}
async function action(d,raw,label){if(!armed||!output()){status('Enable MIDI output before running a command');return;}
 const warning=d.code===1549?(raw===0?'Leaves the optional software as ESC: edits made in it are put back.':'Leaves the optional software as ENTER, keeping '+(raw===1?'sound edits (loops, start / end and play mode go back).':raw===2?'everything on the edit voice; other bank voices keep sound edits only.':'everything, bank voices included.')):d.code===1551?'The current chop is let go: its slices stay in the bank as plain voices, and the next chop starts new.':d.code===1548?'The voice picked with VOICE PICK becomes the edit voice.':d.code===382?'Copies the edit voice into the first empty voice (sharing its sample memory) and edits the copy.':d.code===16?'Selects the first empty voice; existing voice data is not replaced.':d.code===118?'Render is more reliable than Live FX, but destructively processes the sample. Save an untouched copy before continuing.':'This command changes FZ memory or playback state. Existing sample data may be replaced. Continue?';
 if(await confirmAction(label,warning)){
  sendCommand(d,raw,label);
 }
}
function sendCommand(d,raw,label,send=enqueue){  // CREATE SLICES: re-arm (CC98 < 64) first, then give PERF time before 127
 if(d.code===98&&raw>=120){send([[98,0]],'Chop re-arm',null,150);send(encode(d,raw),label);return;}
 send(commandPackets(d,raw),label);
}
function liveSteps(d){
 if(d.code===1541){const n=2+(((state.values['cc:1536']??127)*7)>>7)+1;return Array.from({length:n},(_,i)=>((i*128+64)/n)|0);}  // SUSTAIN AT: none + each segment
 if(d.code===378){const n=4<<((state.values['cc:99']??40)>>5);return Array.from({length:n},(_,i)=>((i*128+64)/n)|0);}  // slice: the chop's slice count
 return d.steps;
}
function options(d){const values=d.clockValues&&state.values['cc:93']>=86?d.clockValues:d.values;const steps=liveSteps(d);if(steps&&steps.length>=2)return steps.map(raw=>[raw,values[raw]]);const unique=[...new Set(values)];if(unique.length>20||unique.length<2)return null;return unique.map(text=>[values.indexOf(text),text]);}
function stepIndex(steps,raw){if(raw===undefined)return -1;let best=0,dist=Infinity;steps.forEach((r,i)=>{const x=Math.abs(r-raw);if(x<dist){dist=x;best=i;}});return best;}
function makeSwitch(d,opts){  // two choices: a two-way switch
 const box=node('div',{class:'switch',role:'group','aria-label':d.label});
 for(const [raw,text] of opts){const b=button(text,null,()=>change(d,raw));b.dataset.raw=raw;b.setAttribute('aria-pressed','false');box.append(b);}
 box.show=raw=>{const i=stepIndex(opts.map(o=>o[0]),raw);[...box.children].forEach((b,j)=>b.setAttribute('aria-pressed',String(j===i)));};
 return box;
}
function makeKnob(d,opts){  // a stepped pot: drag up / down, mouse wheel or arrow keys, one step at a time
 const steps=opts.map(o=>o[0]),k=node('div',{class:'knob',role:'slider',tabindex:0,'aria-label':d.label,'aria-valuemin':0,'aria-valuemax':steps.length-1});
 const dial=node('div',{class:'knob-dial'}),pointer=node('div',{class:'knob-pointer'});dial.append(pointer);
 k.append(dial,node('span',{class:'knob-steps'},steps.length+' steps'));
 let idx=-1,drag=false,startY=0,startIdx=0;const px=Math.max(3,Math.min(14,Math.round(180/steps.length)));
 k.show=raw=>{idx=stepIndex(steps,raw);pointer.style.transform=`rotate(${idx<0?-135:-135+270*idx/Math.max(1,steps.length-1)}deg)`;pointer.style.opacity=idx<0?'.3':'1';k.setAttribute('aria-valuenow',String(Math.max(0,idx)));k.setAttribute('aria-valuetext',idx<0?'—':opts[idx][1]);};
 k.stepTo=i=>{i=Math.max(0,Math.min(steps.length-1,i));if(i!==idx||state.values[key(d)]===undefined)change(d,steps[i]);};
 k.onpointerdown=e=>{drag=true;startY=e.clientY;startIdx=Math.max(0,idx);try{k.setPointerCapture(e.pointerId);}catch{}e.preventDefault?.();k.focus?.();};
 k.onpointermove=e=>{if(!drag)return;const n=startIdx+Math.round((startY-e.clientY)/px);if(n!==idx)k.stepTo(n);};
 k.onpointerup=k.onpointercancel=()=>{drag=false;};
 k.onwheel=e=>{e.preventDefault?.();k.stepTo(Math.max(0,idx)+(e.deltaY<0?1:-1));};
 k.onkeydown=e=>{const big=Math.max(1,Math.ceil(steps.length/8)),m={ArrowUp:1,ArrowRight:1,ArrowDown:-1,ArrowLeft:-1,PageUp:big,PageDown:-big};
  if(e.key in m){e.preventDefault?.();k.stepTo(Math.max(0,idx)+m[e.key]);}else if(e.key==='Home'){e.preventDefault?.();k.stepTo(0);}else if(e.key==='End'){e.preventDefault?.();k.stepTo(steps.length-1);}};
 return k;
}
function bankGuide(){
 const box=node('div',{class:'bank-guide'});box.append(node('h2',{},'Build sequence'));
 const list=node('ol',{});
 for(const [title,text] of [
  ['Choose the target bank (optional)','BANK SELECT plays a bank and makes it the target for adds. Turn it back to VOICE MODE to keep recording and editing. With no bank chosen, adds go to a bank named FZED BANK, which is created in the first empty bank if there is none.'],
  ['Set the MIDI channel','CH in the top bar is the channel the next voice is added on. One voice per channel: adding again on the same channel replaces that place.'],
  ['Make a sound','NEW VOICE moves editing to the first empty voice, so the voices already in the bank are kept. Then record, load a preset wave or chop. COPY VOICE copies the edit voice (sharing its sample memory). VOICE PICK + VOICE SELECT edits a voice that already exists.'],
  ['Shape it','Use the other pages: filter, envelopes, key range, loops, stretch, FX.'],
  ['Add it','BANK ADD / CLEAR · Add this voice puts the edit voice in the target bank on this channel, with its own key range. Clear this MIDI channel removes that channel’s place.'],
  ['Chops into the bank','CHOP INTO · TARGET BANK puts the slices of the next chop after the places already in the target bank, on this channel. FREEZE CHOP lets the chop go, so the next one starts new (on a different channel, for example).'],
  ['Repeat','Change CH, then NEW VOICE again for the next sound.'],
  ['Play and keep it','BANK SELECT plays the bank. Leave with EXIT FZED on the Record page: KEEP ALL keeps every edit, including the bank voices’ loops and start / end.']
 ]){const li=node('li',{});li.append(node('b',{},title+'. '),document.createTextNode(text));list.append(li);}
 box.append(list,node('p',{class:'fx-warning'},'Recording, NEW VOICE and capture are refused in bank mode: return BANK SELECT to VOICE MODE first. A bank holds 64 places.'));
 return box;
}
function fxVariant(raw){return fxOrder[Math.min(14,(raw*15)>>7)];}
// Page layouts: rows of functional groups (slots). The editor isn't bound to the Gills' pots per page,
// so controls are grouped by what they do. Any slot not listed goes in the last group marked '*'
// (or a final MORE group).
const pageLayouts={  // Gills Core 110: P1-P5 top row, P6-P10 bottom row; slots = pots
 voice:[[['Filter',[0,1]],['Speed',[2]]],[['Keys',[5,6,7]]]],
 adsr:[[['Amp (DCA)',[0,1,2,3,4]]],[['Filter (DCF)',[5,6,7,8,9]]]],
 envelope:[[['Amp (DCA)',[0,1,2,3]]],[['Filter (DCF)',[5,6,7,8]]]],
 lfo1:[[['LFO 1',[0,1,2,3]]],[['Depth',[5,6,7,8]]]],
 lfo2:[[['LFO 2',[0,1,2,3,4]]],[['Route 1',[5,6]],[null,1],['Route 2',[8,9]]]],  // null: an empty pot (P8)
 velocity:[[['Velocity',[0,1,2,3,4]]],[['Amp key',[5,6]],['Filter key',[7,8]]]],
 controllers:[[['LFO depth',[0,1,2,3]],['Glide',[4]]],[['Voice',[5]],['Offset',[6,7,8]],['Glide',[9]]]],
 matrix:[[['Routes 1-5',[0,1,2,3,4]]],[['Routes 6-10',[5,6,7,8,9]]]],
 loop:[[['Sample',[0,1,2]],['Window',[3,4]]],[['Loop',[5,6,7,8]],['Preset wave',[9]]]],
 stretch:[[['Stretch',[0,1]],['Grain',[2,3,4]]],[['Segments',[5,6,7,8]],['On / off',[9]]]],
 record:[[['Setup',[0,1,2,3,4]]],[['Take',[5,6,7,8]],['Exit',[9]]]],
 capture:[[['Capture',[6,7,5]],['Setup',[0,1,2]]],[['Hold / pitch',[3,4,9]]],[['Chord',[10,11,12,13,14]]]],
 chop:[[['Chop',[0,1,2,3,4]]],[['Pattern',[5,6,7]],['Into bank',[8,10]],['Filter',[9]]]],
 slices:[[['Slice',[0,1,2,3]],['Output',[4]]],[['Choke',[5]],['Slice voice',[6,8,9]]]],
 fx:[[['Effect',[0]],['Parameters','*']],[['Output',[5,6,9]]]],
 bank:[[['Voice',[0,1,2,3]]],[['Bank',[4,5]],['Chops',[6,7]]]]
};
function layoutTiles(tiles){
 const box=$('controls'),spec=pageLayouts[state.group];
 if(!spec){box.append(...tiles);return;}
 const bySlot=new Map(tiles.map(t=>[Number(t.getAttribute('data-slot')),t]));const used=new Set();
 for(const row of spec)for(const [,slots] of row)if(Array.isArray(slots))for(const s of slots)used.add(s);
 const rest=tiles.filter(t=>!used.has(Number(t.getAttribute('data-slot'))));let restPlaced=false;
 const group=(title,items)=>{const g=node('section',{class:'control-group',style:`--cols:${items.length}`,'aria-label':title});g.append(node('div',{class:'group-label'},title));const grid=node('div',{class:'group-grid'});grid.append(...items);g.append(grid);return g;};
 for(const row of spec){const r=node('div',{class:'control-row'});
  for(const [title,slots] of row){if(title===null){r.append(node('div',{class:'control-group control-gap',style:`--cols:${slots}`,'aria-hidden':'true'}));continue;}const items=slots==='*'?(restPlaced=true,rest):slots.map(s=>bySlot.get(s)).filter(Boolean);if(items.length)r.append(group(title,items));}
  if(r.children.length)box.append(r);}
 if(!restPlaced&&rest.length){const r=node('div',{class:'control-row'});r.append(group('More',rest));box.append(r);}
}
function render(){
 learning=null;
 const idx=groups.findIndex(g=>g[0]===state.group);$('pageIndex').textContent=`FZ / ${String(idx+1).padStart(2,'0')}`;$('pageTitle').textContent=groups[idx][1];$('pageDescription').textContent=pageDescriptions[state.group]??'';$('pageDescription').hidden=!pageDescriptions[state.group];
 for(const b of $('navigation').children)b.classList.toggle('active',b.dataset.group===state.group);
 $('subviews').replaceChildren();let variants=[];
 if(state.group==='fx')$('subviews').append(node('p',{class:'fx-warning'},'Live FX may not work above 9 kHz; short samples may work. Render is more reliable but destructive. Back up the sample first.'));
 $('sendPage').disabled=state.group==='user';$('clearLearn').disabled=state.group==='user';
 if(state.group==='user'){$('controls').classList.remove('grouped');renderUserBank();icons();return;}
 if(state.group==='envelope')variants=Array.from({length:8},(_,i)=>[i+1,`Step ${i+1}`]);
 if(state.group==='controllers')variants=[[0,'Mod wheel'],[1,'Foot'],[2,'Aftertouch']];
 if(state.group==='matrix')variants=[[0,'Source'],[2,'Destination'],[1,'Amount']];
 if(state.group==='chop'){
  const rate=state.values['cc:265']??0,clock=rate>=64;
  const mode=node('div',{class:'pattern-rate-mode','role':'group','aria-label':'Pattern rate mode'});
  for(const [isClock,label] of [[false,'Free'],[true,'MIDI Clock']]){const b=button(label,null,()=>{const currentRate=state.values['cc:265']??0,offset=isClock?64:0,within=isClock?Math.max(0,currentRate-64):Math.min(63,currentRate);change(profile.controls.find(d=>d.group==='chop'&&d.code===265),offset+within);});b.setAttribute('aria-pressed',String(clock===isClock));mode.append(b);}
  $('subviews').append(mode,node('p',{class:'fx-warning'},'Pattern Rate displays either free milliseconds per step or a MIDI-clock division.'));
 }
 for(const [v,label] of variants){const b=button(label,null,()=>{state.variants[state.group]=v;render();});b.setAttribute('aria-pressed',String(state.variants[state.group]===v));$('subviews').append(b);}
 if(state.group==='matrix'&&state.variants.matrix===1)$('subviews').append(node('p',{class:'fx-warning'},'Amount is bipolar: −64 to +64, with 0 at the center.'));
 if(state.group==='bank')$('subviews').append(bankGuide());
 if(!['user','bank','record','capture'].includes(state.group))$('subviews').append(presetBar());
 if(state.group==='lfo2')$('subviews').append(node('p',{class:'fx-warning'},'Mode selects Free, Note Retrigger or MIDI Clock. Rate / Division is a free rate index in Free and Note Retrigger modes, and a named clock division in MIDI Clock mode.'));
 $('controls').replaceChildren();$('controls').classList.toggle('grouped',!!pageLayouts[state.group]);const pageTiles=[];
 for(const d of current()){
 const tile=node('article',{class:'control'+(isAction(d)?' action-control':''),'data-slot':d.slot});const head=node('div',{class:'control-head'});let label=state.group==='fx'&&d.slot===0?'FX TYPE':d.label;if(state.group==='fx'&&d.variant===2&&d.slot===6)label='LIVE: TAPEHACK ONLY';head.append(node('h3',{},label));
 if(!isAction(d)){const learn=button('','radio',()=>{learning=mapKey(d);document.querySelectorAll('.learn').forEach(x=>x.classList.remove('learning'));learn.classList.add('learning');status('MIDI Learn · move one input control');},`Learn ${label}`);learn.className='learn';head.append(learn);}
 tile.append(head,node('output',{},''));
 if(state.group==='record'&&d.code===110)tile.append(node('p',{class:'control-help'},'At 36 kHz, RATE CUT records without anti-aliasing. At 18, 9, and 4.5 kHz, RATE CUT applies the appropriate slope. A different cutoff keeps filtering while adding grit.'));
 if(state.group==='voice'&&(d.code===66||d.code===67))tile.append(node('p',{class:'control-help'},'The full CC range 0–127 spans FZ key numbers 36–96.'));
 if(isAction(d)){for(const [raw,commandLabel] of actionOptions(d)){const row=node('div',{class:'action-row'});row.append(button(commandLabel,'play',()=>action(d,raw,commandLabel)));const learn=button('','radio',()=>{learning=mapKey(d,raw);document.querySelectorAll('.learn').forEach(x=>x.classList.remove('learning'));learn.classList.add('learning');status(`MIDI Learn · move a control for ${commandLabel}`);},`Learn ${commandLabel}`);learn.className='learn';row.append(learn);tile.append(row);}}
 else{
 const opts=options(d);
 if(opts)tile.append(opts.length===2?makeSwitch(d,opts):makeKnob(d,opts));
 else{const signed=isSignedControl(d),limit=signedKind(d);const slider=node('input',{type:'range',min:0,max:127,value:state.values[key(d)]??64,'aria-label':d.label});slider.oninput=()=>change(d,Number(slider.value));tile.append(slider);if(signed){const scale=node('div',{class:'signed-scale'});scale.append(node('span',{},`−${limit}`),node('span',{},'0'),node('span',{},`+${limit}`));tile.append(scale);}}
 }
 const meta=node('div',{class:'control-meta'});meta.append(node('span',{},d.sequence.map(([cc,v])=>`CC${cc}${v===null?'':':'+v}`).join(' / ')));
 if(!isAction(d)){const signed=isSignedControl(d),limit=signedKind(d);const number=node('input',{type:'number',min:signed?-limit:0,max:signed?limit:127,placeholder:'—','aria-label':signed?`${d.label} signed value −${limit} to +${limit}`:`${d.label} raw MIDI`});number.onchange=()=>{const v=Number(number.value);if(number.value!==''&&Number.isInteger(v)&&v>=(signed?-limit:0)&&v<=(signed?limit:127)){const raw=signed?rawForSigned(d,v):v;if(raw>=0)change(d,raw);else updateControls();}else updateControls();};meta.append(number);}
 const mappings=isAction(d)?actionOptions(d).map(([raw,label])=>({label,m:state.mappings[mapKey(d,raw)]})).filter(x=>x.m):[{m:state.mappings[mapKey(d)]}].filter(x=>x.m);
 for(const {label,m}of mappings)meta.append(node('span',{},`Learn CH${m.channel+1} CC${m.cc}${label?' · '+label:''}`));
 tile.append(meta);pageTiles.push(tile);
 }
 layoutTiles(pageTiles);
 $('extraActions').replaceChildren();if(state.group==='loop')$('extraActions').append(button('Load selected wave','replace',loadWave));
 if(state.group==='fx'){
  const raw=state.values['cc:112']??0,variant=fxVariant(raw),selected=profile.controls.find(d=>d.group==='fx'&&d.variant===variant&&d.slot===0),effectName=selected?.values[raw]??'';
  for(const code of [100,101]){const d=profile.controls.find(c=>c.group==='fx'&&c.variant===variant&&c.code===code);if(!d)continue;const [commandRaw,label]=actionOptions(d)[0],command=button(label,'play',()=>action(d,commandRaw,label));const learn=button('','radio',()=>{learning=mapKey(d,commandRaw);document.querySelectorAll('.learn').forEach(x=>x.classList.remove('learning'));learn.classList.add('learning');status(`MIDI Learn · move a control for ${label}`);},`Learn ${label}`);learn.className='learn';$('extraActions').append(command,learn);}
  if(['FILTER','POCKEY2','TAPEHACK > POCKEY2'].includes(effectName))$('extraActions').append(node('p',{class:'fx-mode-note'},effectName==='FILTER'?'Filter is primarily a Render effect; Live FX is available.':effectName==='POCKEY2'?'Pockey2 runs as a Render effect.':'Live processing runs the TapeHack stage only; bits and DeFreq take effect on Render.'));
 }
 $('diagram').hidden=!['adsr','envelope'].includes(state.group);updateControls();icons();
}
async function loadWave(){const d=profile.controls.find(c=>c.code===111);const raw=state.values[key(d)];if(raw===undefined||raw<8){status('Select a preset wave first');return;}
 if(!armed||!output()){status('Enable MIDI output before loading a wave');return;}
 if(await confirmAction('Replace with '+human(d,raw)+'?', 'The current voice/sample may be replaced. This cannot be undone by the editor.'))enqueue([[111,raw],[9,0],[9,127]],'Load preset wave');
}
function drawEnvelope(){if($('diagram').hidden)return;const c=$('envelopeCanvas');const ctx=c.getContext('2d');ctx.clearRect(0,0,c.width,c.height);if(state.group==='envelope'){ctx.fillStyle='rgba(24,36,94,.13)';ctx.fillRect(24+(state.variants.envelope-1)*105,12,105,78);}ctx.strokeStyle='rgba(24,36,94,.3)';ctx.lineWidth=1;for(let i=0;i<9;i++){ctx.beginPath();ctx.moveTo(24+i*105,12);ctx.lineTo(24+i*105,90);ctx.stroke();}
 for(const [kind,color] of [[0,'#18245e'],[1,'#3d5aa8']]){ctx.strokeStyle=color;ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(24,88);
  if(state.group==='adsr'){
   const base=kind?82:78,values=[0,1,2,3].map(i=>state.values['cc:'+(base+i)]);
   if(values.some(v=>v!==undefined)){const a=30+(values[0]??0),dec=30+(values[1]??0),r=30+(values[3]??0),scale=840/(a+dec+r+100),s=88-(values[2]??0)*.55;ctx.lineTo(24+a*scale,18);ctx.lineTo(24+(a+dec)*scale,s);ctx.lineTo(24+(a+dec+100)*scale,s);ctx.lineTo(864,88);}
  }else for(let s=1;s<=8;s++){const d=profile.controls.find(d=>d.group==='envelope'&&d.variant===s&&d.slot===(kind?3:1));const v=state.values[key(d)];ctx.lineTo(24+s*105,88-(v??0)*.55);}
  ctx.stroke();}ctx.fillStyle='#18245e';ctx.font='11px "FZED LCD", monospace';ctx.fillText(state.group==='adsr'?'DCA / DCF · local ADSR schematic':'DCA / DCF · local stage levels',32,18);
}
// ---- User presets: the Gills USER_FZ.BIN bank (GLUSER01, 100 slots of 544 bytes). Slot: name (12), device 4, used,
// known / total counts, values[256] (CC 0-127, then parameter 0-127 at 128+; FFh = not set), raw pot positions[256], and
// (FZED / Gills Core 109) STRETCH and per-slice values at bytes 530-541: 'S' then the PERF controls in EXT order.
const BANK_SIZE=54416,SLOT=544,EXT=[0,1,2,3,4,5,6,7,8,10,9];  // Gills STRETCH-view keys; on / off last, so it builds once
const BANK_STORE='fzed-user-bank-v1';
function emptyBank(){const b=new Uint8Array(BANK_SIZE);b.set([...'GLUSER01'].map(c=>c.charCodeAt(0)),0);b[8]=4;b[10]=100;b[12]=SLOT&255;b[13]=SLOT>>8;return b;}
function parseUserBank(bytes){
 if(!(bytes instanceof Uint8Array)||bytes.length!==BANK_SIZE)throw Error('Expected a 54,416-byte USER_FZ.BIN');
 const view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);
 if(String.fromCharCode(...bytes.subarray(0,8))!=='GLUSER01'||view.getUint16(8,true)!==4||view.getUint16(10,true)!==100||view.getUint16(12,true)!==SLOT)throw Error('Invalid FZ user-bank header');
 const presets=[];
 for(let i=0;i<100;i++){
  const start=16+i*SLOT,used=bytes[start+13];if(used===0)continue;
  if(used!==1||bytes[start+12]!==4)throw Error('Invalid preset device / used flag at slot '+(i+1));
  const nameBytes=bytes.subarray(start,start+12);if([...nameBytes].some(v=>v<32||v>126))throw Error('Invalid preset name');
  const values=[...bytes.subarray(start+18,start+274)],raws=[...bytes.subarray(start+274,start+530)];
  if([...values,...raws].some(v=>v>127&&v!==255))throw Error('Invalid preset value');
  const known=view.getUint16(start+14,true),total=view.getUint16(start+16,true);if(known>256||total>256||known>total)throw Error('Invalid preset parameter count');
  const ext=bytes[start+530]===0x53?[...bytes.subarray(start+531,start+531+EXT.length)].map(v=>v>127?255:v):EXT.map(()=>255);
  presets.push({slot:i+1,name:String.fromCharCode(...nameBytes).trim(),known,total,values,raws,ext});
 }
 return {bytes:new Uint8Array(bytes),presets};
}
const bankExcluded=new Set([9,10,11,14,15,16,98,100,101,106,107,108,109,111,118,120,121,122,123,124,125,126,127,135]);
const safeBankCC=new Set(profile.controls.filter(d=>d.code<128&&!isAction(d)&&!bankExcluded.has(d.code)).map(d=>d.code));
const muxControl=k=>k>=6&&k<=8?k+10:k;  // Gills STRETCH-view key -> PERF control number
function bankEntries(preset){
 const entries=[];
 if(preset.values[248]!==255)entries.push({index:248,value:preset.values[248],packets:[[10,120],[11,preset.values[248]]]});
 for(let k=0;k<256;k++){
  const value=preset.values[k];if(value===255||k===248||bankExcluded.has(k))continue;
  if(k<128){if(safeBankCC.has(k))entries.push({index:k,value,packets:[[k,value]]});}
  else{const id=k-128;if((id<=87&&id!==7)||(id>=90&&id<120))entries.push({index:k,value,packets:[[10,id],[11,value]]});}
 }
 EXT.forEach((k,j)=>{const value=preset.ext?.[j];if(value!==undefined&&value!==255)entries.push({index:'ext:'+k,ext:k,value,packets:mux(muxControl(k),value)});});
 return entries;
}
// where a control lives in a preset slot (null = not stored, as on the Gills: commands, capture, bank actions)
function presetIndex(d){
 if(d.synthetic||isAction(d)||d.group==='capture'||d.group==='capture2')return null;
 const s=d.sequence;
 if(s.length===1&&s[0][1]===null){const cc=s[0][0];return bankExcluded.has(cc)?null:{i:cc};}
 if(s.length===2&&s[0][0]===10&&s[1][0]===11&&s[1][1]===null){const id=s[0][1];return bankExcluded.has(128+id)||id===88||id===89||id>=120?null:{i:128+id};}
 if(s.length===4&&s[0][1]===88&&d.code>=1536&&d.code<1552){const j=EXT.indexOf(d.code-1536);return j<0?null:{x:j};}
 return null;
}
function presetPages(preset){  // the pages that hold every one of the preset's settings (empty for a whole-voice preset)
 let pages=null;
 let matrixOnly=false;
 for(const e of bankEntries(preset)){if(e.index===248)continue;const here=new Set(descriptorsFor(e,preset).map(descriptorPage));
  if(here.has('matrix')){matrixOnly=true;continue;}  // a matrix route that goes with a page's preset (a pattern's route, say)
  pages=pages===null?here:new Set([...pages].filter(p=>here.has(p)));}
 return pages??new Set(matrixOnly?['matrix']:[]);
}
function descriptorsFor(e,preset){
 if(e.ext!==undefined)return profile.controls.filter(d=>d.code===1536+e.ext&&!d.synthetic);
 const fx=fxVariant(preset.values[112]!==255?preset.values[112]:(state.values['cc:112']??0));
 if(typeof e.index==='number'&&e.index<128)return profile.controls.filter(d=>d.code===e.index&&d.sequence.length===1&&!['capture','capture2'].includes(d.group)&&(d.group!=='fx'||d.variant===fx));
 return profile.controls.filter(d=>d.sequence.length===2&&d.sequence[0][0]===10&&d.sequence[0][1]===e.index-128);
}
function openUserPreset(preset,localOnly=true){
 if(localOnly)setArmed(false);const entries=bankEntries(preset);
 if(entries.some(e=>e.index===248&&e.value>=64)){
  for(let id=90;id<120;id++)state.values['param:'+id]=id<100||id>=110?0:64;
  state.values['param:1']=0;state.values['param:2']=0;
 }
 const effect=entries.find(e=>e.index===112)?.value;
 if(effect!==undefined)state.variants.fx=fxVariant(effect);
 for(const e of entries){
  if(e.index===248)continue;
  for(const descriptor of descriptorsFor(e,preset)){const preferred=typeof e.index==='number'?preset.raws[e.index]:e.value;const raw=preferred<=127&&descriptor.wireValues[preferred]===e.value?preferred:descriptor.wireValues.indexOf(e.value);if(raw>=0)state.values[key(descriptor)]=raw;}
 }
 save();render();status(preset.name+(localOnly?' · opened locally · output locked':' · preset queued'));
}
async function sendUserPreset(preset){
 if(!armed||!output()){status('Enable output before sending a preset');return;}
 const entries=bankEntries(preset);
 if(await confirmAction('Send '+preset.name+'?', 'Apply '+entries.length+' stored settings to the current FZ voice'+(entries.some(e=>e.index===248)?'. This may clear its mod matrix':'')+'. No sample replacement, recording, render, voice INIT or bank commands are sent.')){
  if(!armed||!output()){status('Preset cancelled · output unavailable');return;}
  cancelQueue();openUserPreset(preset,false);for(const entry of entries)enqueue(entry.packets,preset.name+' · '+entry.index,null,20);
 }
}
function storeBank(){try{localStorage.setItem(BANK_STORE,btoa(String.fromCharCode(...userBank.bytes)));}catch{status('Bank kept for this session only (browser storage unavailable)');}}
function setBank(bytes,message){userBank=parseUserBank(bytes);storeBank();render();if(message)status(message);}
function downloadBank(){if(!userBank)return;const blob=new Blob([userBank.bytes],{type:'application/octet-stream'}),url=URL.createObjectURL(blob);node('a',{href:url,download:'USER_FZ.BIN'}).click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
const PATTERN_CODES=new Set([264,265,343]);
function scopeChoices(){
 const here=state.group,label=groups.find(g=>g[0]===here)?.[1]??here,list=[['all','Whole voice (every page)']];
 if(here!=='user'&&here!=='bank'&&here!=='capture'&&here!=='record')list.unshift(['page','This page: '+label]);
 if(here==='chop')list.splice(1,0,['pattern','Pattern only']);
 return list;
}
function presetSlotBytes(name,scope){  // the current settings, as a slot (or null if nothing is set)
 const slot=new Uint8Array(SLOT);slot.fill(32,0,12);slot.fill(255,18,530);let known=0,ext=false;
 const fx=state.values['cc:112']===undefined?null:fxVariant(state.values['cc:112']);
 for(const d of profile.controls){
  const where=presetIndex(d);if(!where)continue;
  if(d.group==='fx'&&d.code!==112&&d.variant!==fx)continue;
  if(scope==='pattern'&&!PATTERN_CODES.has(d.code))continue;
  if(scope==='page'&&descriptorPage(d)!==state.group)continue;
  const raw=state.values[key(d)];if(raw===undefined)continue;
  if(where.x!==undefined){if(!ext){slot.fill(255,531,531+EXT.length);slot[530]=0x53;ext=true;}slot[531+where.x]=d.wireValues[raw];continue;}
  if(slot[18+where.i]===255)known++;slot[18+where.i]=d.wireValues[raw];slot[274+where.i]=raw;
 }
 if(!ext)slot.fill(0,530,SLOT);
 if(!known&&!ext)return null;
 const clean=(name.toUpperCase().replace(/[^\x20-\x7e]/g,'').slice(0,12)||'USER').padEnd(12,' ');
 for(let i=0;i<12;i++)slot[i]=clean.charCodeAt(i);
 slot[12]=4;slot[13]=1;slot[14]=known&255;slot[15]=known>>8;slot[16]=known&255;slot[17]=known>>8;
 return slot;
}
function writeSlot(n,slotBytes){const b=new Uint8Array(userBank?.bytes??emptyBank());b.set(slotBytes??new Uint8Array(SLOT),16+(n-1)*SLOT);return b;}
function presetDialog(title,{name='',slot=null,scope=null}={}){
 const dlg=$('presetDialog');if(dlg.open)return Promise.resolve(null);
 $('presetTitle').textContent=title;$('presetName').value=name;
 const slots=$('presetSlot');slots.replaceChildren();const used=new Map((userBank?.presets??[]).map(p=>[p.slot,p.name]));
 let first=null;for(let i=1;i<=100;i++){if(first===null&&!used.has(i))first=i;slots.append(node('option',{value:i},String(i).padStart(3,'0')+' · '+(used.get(i)??'empty')));}
 slots.value=String(slot??first??1);$('presetSlotRow').hidden=slot!==null&&scope===null;
 const scopes=$('presetScope');scopes.replaceChildren();for(const [v,t]of scopeChoices())scopes.append(node('option',{value:v},t));
 $('presetScopeRow').hidden=scope===false;if(scope)scopes.value=scope;
 dlg.showModal();
 return new Promise(resolve=>{dlg.onclose=()=>{dlg.onclose=null;resolve(dlg.returnValue==='save'?{name:$('presetName').value,slot:Number(slots.value),scope:scopes.value}:null);dlg.returnValue='';};});
}
async function savePreset(defaultScope){
 const r=await presetDialog('Save as preset',{scope:defaultScope??(scopeChoices()[0][0])});if(!r)return;
 const bytes=presetSlotBytes(r.name,r.scope);if(!bytes){status('Nothing to save: no values set'+(r.scope==='all'?'':' on this page'));return;}
 const old=userBank?.presets.find(p=>p.slot===r.slot);
 if(old&&!await confirmAction('Replace '+old.name+'?','Slot '+r.slot+' already holds '+old.name+'.'))return;
 setBank(writeSlot(r.slot,bytes),'Saved '+r.name.toUpperCase().slice(0,12)+' in slot '+r.slot+' · download USER_FZ.BIN to keep it');
}
async function renamePreset(preset){
 const r=await presetDialog('Rename preset',{name:preset.name,slot:preset.slot,scope:false});if(!r)return;
 const b=new Uint8Array(userBank.bytes),start=16+(preset.slot-1)*SLOT,clean=(r.name.toUpperCase().replace(/[^\x20-\x7e]/g,'').slice(0,12)||'USER').padEnd(12,' ');
 for(let i=0;i<12;i++)b[start+i]=clean.charCodeAt(i);setBank(b,'Renamed to '+clean.trim());
}
async function deletePreset(preset){if(await confirmAction('Delete '+preset.name+'?','Slot '+preset.slot+' becomes empty in the editor’s bank. Download USER_FZ.BIN to keep the change in a file.'))setBank(writeSlot(preset.slot,null),'Deleted '+preset.name);}
function presetTag(preset){const pages=[...presetPages(preset)];if(!pages.length)return bankEntries(preset).length?'Whole voice':'Empty';return pages.map(p=>groups.find(x=>x[0]===p)?.[1]??p).join(' / ');}
function pagePresets(group){if(!userBank)return [];return userBank.presets.filter(p=>presetPages(p).has(group));}
function presetBar(){  // on every editing page: this page's presets and Save as preset
 const bar=node('div',{class:'preset-bar'}),list=pagePresets(state.group);
 bar.append(node('span',{class:'preset-bar-label'},'Presets'));
 if(list.length){const sel=node('select',{'aria-label':'Presets for this page'});sel.append(node('option',{value:''},list.length+' for this page…'));for(const p of list)sel.append(node('option',{value:p.slot},p.name));
  const open=button('Open','folder-open',()=>{const p=list.find(x=>x.slot===Number(sel.value));if(p)openUserPreset(p);else status('Choose a preset first');});
  const send=button('Send','send',()=>{const p=list.find(x=>x.slot===Number(sel.value));if(p)sendUserPreset(p);else status('Choose a preset first');});
  bar.append(sel,open,send);}
 else bar.append(node('span',{class:'preset-bar-empty'},'none for this page yet'));
 bar.append(button('Save as preset…','save',()=>savePreset()));
 return bar;
}
function renderUserBank(){
 $('diagram').hidden=true;$('controls').replaceChildren();$('extraActions').replaceChildren();
 const file=node('input',{type:'file',accept:'.bin,application/octet-stream',hidden:true,id:'bankFile'});
 file.onchange=async()=>{try{const source=file.files[0];if(!source)return;if(source.size!==BANK_SIZE)throw Error('Invalid bank size');const next=new Uint8Array(await source.arrayBuffer());parseUserBank(next);setArmed(false);setBank(next,'User bank opened locally · output locked');}catch(e){status('Bank refused: '+e.message);}finally{file.value='';}};
 $('subviews').append(button('Save current voice as preset…','save',()=>savePreset('all')),button('Open USER_FZ.BIN','folder-open',()=>file.click()),button('Download USER_FZ.BIN','download',downloadBank),
  button('Bundled bank','rotate-ccw',async()=>{if(await confirmAction('Load the bundled bank?','Replaces the editor’s bank with the bank that comes with FZED. Download USER_FZ.BIN first to keep the current one.'))setBank(bundledBank(),'Bundled bank loaded');}),
  button('New empty bank','file-plus',async()=>{if(await confirmAction('Start an empty bank?','Replaces the editor’s bank with 100 empty slots. Download the current one first if you want to keep it.'))setBank(emptyBank(),'Empty bank');}),file);
 if(!userBank){$('controls').append(node('p',{},'No user bank'));return;}
 $('subviews').append(node('span',{class:'bank-summary'},userBank.presets.length+' presets / 100 slots · this bank lives in the browser until you download it'));
 for(const preset of userBank.presets){
  const tile=node('article',{class:'control preset'});
  const ext=preset.ext?.some(v=>v!==255)?' · stretch':'';
  tile.append(node('h3',{},String(preset.slot).padStart(3,'0')+' / '+preset.name),node('output',{},presetTag(preset)+' · '+(preset.known+(preset.ext?.filter(v=>v!==255).length??0))+' settings'+ext));
  const row=node('div',{class:'preset-actions'});
  row.append(button('Open','folder-open',()=>openUserPreset(preset)),button('Send','send',()=>sendUserPreset(preset)),button('Rename','pencil',()=>renamePreset(preset)),button('Delete','trash-2',()=>deletePreset(preset)));
  tile.append(row);$('controls').append(tile);
 }
}
function bundledBank(){return window.FZ_USER_BANK?Uint8Array.from(atob(window.FZ_USER_BANK.base64),ch=>ch.charCodeAt(0)):emptyBank();}
function fillPorts(){const oldIn=$('inputPort').value,oldOut=$('outputPort').value;for(const [id,ports]of [['inputPort',access.inputs],['outputPort',access.outputs]]){const select=$(id);select.replaceChildren(node('option',{value:''},'None'));if(id==='inputPort')select.append(node('option',{value:'*'},'All inputs'));for(const port of ports.values())if(port.state!=='disconnected')select.append(node('option',{value:port.id},port.name||port.id));}if(access.inputs.has(oldIn)||oldIn==='*')$('inputPort').value=oldIn;if(access.outputs.has(oldOut))$('outputPort').value=oldOut;for(const input of access.inputs.values())input.onmidimessage=event=>incoming(input,event.data);}
async function connect(){try{if(!navigator.requestMIDIAccess)throw Error('Web MIDI requires a supported browser on localhost or HTTPS');access=await navigator.requestMIDIAccess({sysex:false});fillPorts();access.onstatechange=()=>{setArmed(false);fillPorts();status('MIDI ports changed · output locked');};status('MIDI connected · select ports, then enable output');}catch(e){status(e.message);}}
// ---- Novation ReMOTE SL with the FZED templates: every CC from the SL input port, any channel. ----
// CC n = a PERF CC with its FZED value. NRPN (CC99 / CC98, value on CC6): 0 / p = PERF parameter p (CC10 / CC11),
// 1 / k = PERF control k (parameter 88 / 89), 2 / f = FZED function, 3 = selected envelope step, 4 = selected
// controller source, 5 = selected matrix route, 6 = FX parameter of the current effect, 7 / n = PERF CC n (CC98 / CC99).
const slNr={msb:null,lsb:null};let slRoute=0;
function slMode(){return $('inputValues')?.value==='sl';}
function slForward(){return $('followMode').value==='forward';}
function slIsCommandCc(cc){return cc===9||profile.controls.some(d=>d.code===cc&&isAction(d));}
function slSend(packets,label,id=null,pace=8){if(slForward())enqueue(packets,label,id,pace);else for(const [cc,v] of packets)fzEcho(cc,v);}
function slTarget(ds,v,fallback=null){
 ds=ds.filter(Boolean);
 if(!ds.length){if(fallback)slSend(fallback,'Remote SL');return null;}
 const act=ds.find(d=>isAction(d)&&d.code!==108);
 if(act){const raw=descriptorRaw(act,v);slSend(encode(act,raw),`${act.label} · ${v}`);return act;}
 const shown=applyFollowDescriptors(ds,v);
 const d=ds.find(x=>descriptorPage(x)===state.group)??ds[0],raw=descriptorRaw(d,v);
 if(raw>=0)slSend(encode(d,raw),`${d.label} · ${human(d,raw)}`,key(d));
 return shown;
}
function slDirect(cc,v){
 const ds=resolvePlainCc(cc,v);if(ds.length)applyFollowDescriptors(ds,v);
 slSend([[cc,v]],ds[0]?`${ds[0].label} · ${v}`:`CC${cc} · ${v}`,slIsCommandCc(cc)?null:`sl:cc:${cc}`);
}
function slGo(group){state.group=group;render();}
function slFunction(f,v){
 const find=code=>profile.controls.find(d=>d.code===code);
 if(f===0){const i=groups.findIndex(g=>g[0]===state.group);slGo(groups[(i+(v>=64?1:groups.length-1))%groups.length][0]);return;}
 if(f===1){state.variants.envelope=Math.min(8,v+1);slGo('envelope');return;}
 if(f===2){state.variants.controllers=Math.min(2,v);slGo('controllers');return;}
 if(f===3){slRoute=Math.min(9,v);slGo('matrix');status(`Remote SL · matrix route ${slRoute+1}`);return;}
 if(f===4){const d=find(1549),raw=Math.min(3,v);if(d)slSend(commandPackets(d,raw),actionOptions(d).find(x=>x[0]===raw)?.[1]??d.label);return;}
 if(f===5){const d=find(1548);if(d&&v>=64)slSend(commandPackets(d,127),d.label);return;}
 if(f===6){slTarget([find(1024)],v);return;}
 if(f===8){const d=profile.controls.find(x=>x.group==='capture'&&x.code===108);if(!d)return;const raw=v>=64?127:0;change(d,raw,false);followPage(d);slSend(commandPackets(d,raw),raw?'CAPTURE ON':'CAPTURE OFF');return;}
 if(f===9){slTarget([find(1282)],v);return;}
}
function slNrpn(msb,lsb,v){
 const P=profile.controls;
 if(msb===0){slTarget(P.filter(d=>d.sequence.length===2&&d.sequence[0][0]===10&&d.sequence[0][1]===lsb&&d.sequence[1][0]===11&&d.sequence[1][1]===null),v,[[10,lsb],[11,v]]);return;}
 if(msb===1){slTarget(P.filter(d=>d.sequence.length===4&&d.sequence[0][1]===88&&d.sequence[1][1]===lsb),v,mux(lsb,v));return;}
 if(msb===2){slFunction(lsb,v);return;}
 if(msb===3){const slot=[0,1,5,6][lsb];slTarget([P.find(d=>d.group==='envelope'&&d.variant===state.variants.envelope&&d.slot===slot)],v);return;}
 if(msb===4){const slot=[0,1,2,3,6,7,8][lsb];slTarget([P.find(d=>d.group==='controllers'&&d.variant===state.variants.controllers&&d.slot===slot)],v);return;}
 if(msb===5&&lsb<=2){slTarget([P.find(d=>d.group==='matrix'&&d.variant===lsb&&d.slot===slRoute)],v);return;}
 if(msb===6){const variant=fxVariant(state.values['cc:112']??0);if(!fxUsedSlots[variant]?.includes(lsb)){status(`Remote SL · this effect has no P${lsb+1}`);return;}slTarget([P.find(d=>d.group==='fx'&&d.variant===variant&&d.slot===lsb)],v);return;}
 if(msb===7){if(lsb===98){const d=P.find(x=>x.group==='chop'&&x.code===98);if(d)sendCommand(d,v,actionOptions(d).find(x=>x[0]===v)?.[1]??d.label,slSend);return;}slDirect(lsb,v);return;}
}
function slCc(cc,v){
 if($('followMode').value==='off')return;
 // the SL sends CC99, CC98, then the value as CC6 (7-bit); CC38 and RPN select / null (CC100 / CC101) are dropped
 if(cc===99){slNr.msb=v;return;}if(cc===98){slNr.lsb=v;return;}if(cc===38||cc===100||cc===101)return;
 if(cc===6){if(slNr.msb!==null&&slNr.lsb!==null)slNrpn(slNr.msb,slNr.lsb,v);return;}
 slDirect(cc,v);
}
const monitorLines=[];
function monitorLog(data,dir='IN '){
 const box=$('monitorBox');if(!box||!box.open)return;
 const hex=Array.from(data).map(b=>b.toString(16).padStart(2,'0').toUpperCase()).join(' ');
 const type=data[0]&0xf0,ch=(data[0]&15)+1;let text='';
 if(type===0xb0)text=`ch${ch} CC${data[1]} = ${data[2]}`;else if(type===0x90)text=`ch${ch} note ${data[1]} vel ${data[2]}`;else if(type===0x80)text=`ch${ch} note off ${data[1]}`;else if(type===0xe0)text=`ch${ch} bend`;else if(data[0]===0xf0)text='SysEx';
 monitorLines.push(`${dir} ${hex.padEnd(9)}  ${text}`);while(monitorLines.length>40)monitorLines.shift();
 $('monitor').textContent=monitorLines.join('\n');
}
function listening(input){const v=$('inputPort').value;if(v!=='*')return input.id===v;const out=access?.outputs?.get?.($('outputPort').value);return !(out&&out.name&&out.name===input.name);}  // All inputs: every port but the FZ interface's own
function incoming(input,data){if(!listening(input)||data.length<1)return;monitorLog(data);const type=data[0]&0xf0,ch=data[0]&15;
 if(type===0xb0&&data.length>=3){
  if(slMode()){if(!learning)slCc(data[1],data[2]);return;}
  if($('followMode').value!=='off')fzObserve(data);  // Remote SL: every CC from the SL, on whatever channel it sends
  const cc=data[1],value=data[2],mode=$('followMode').value;
  if(learning&&cc<120&&!plainInput()&&(cc===10||cc===11)){learning=null;document.querySelectorAll('.learning').forEach(x=>x.classList.remove('learning'));status('Learn cancelled: that control sends a CC10/CC11 parameter pair, which Follow tracks without Learn. Learn needs a single CC, or set INPUT VALUES to Plain 0-127');}
  if(learning&&cc<120){const visible=current();if(state.group==='fx'){const variant=fxVariant(state.values['cc:112']??0);visible.push(...profile.controls.filter(d=>d.group==='fx'&&d.variant===variant&&[100,101].includes(d.code)));}const active=new Set(visible.flatMap(d=>isAction(d)?actionOptions(d).map(([raw])=>mapKey(d,raw)):[mapKey(d)]));for(const [k,m]of Object.entries(state.mappings))if(active.has(k)&&m.input===input.id&&m.channel===ch&&m.cc===cc)delete state.mappings[k];state.mappings[learning]={input:input.id,channel:ch,cc};actionEdges.delete(`${input.id}:${ch}:${cc}`);save();render();status('MIDI Learn assigned');return;}
  const learned=plainInput()||(cc!==10&&cc!==11)?learnedDescriptor(input,ch,cc):null;
  if(learned){if(isAction(learned)){if(mode==='forward')triggerLearnedAction(learned,input,ch,cc,value);}else{const raw=incomingRaw(learned,value,cc);if(raw>=0)change(learned,raw,mode!=='display');}return;}
  if(mode!=='off'){
   const observed=profile.controls.find(d=>isAction(d)&&d.code===cc&&d.group==='fx'&&d.variant===fxVariant(state.values['cc:112']??0));if(observed)status(`Observed command · ${observed.label}${value>=64?'':' · re-armed'}`);
   const followed=ch===state.channel?followCc(input,ch,cc,value):null;
   if(mode==='forward'&&ch===state.channel){
    if(!plainInput())forwardIncoming(input,data);  // FZED values: pass the message through unchanged
    else if(followed&&!isAction(followed))enqueue(encode(followed,value),`${followed.label} · ${human(followed,value)}`,key(followed));  // plain 0-127: send the scaled FZED message
   }
   return;
  }
  if($('thru').checked&&[1,2,4,7,64,120,123].includes(cc)&&armed){rememberEndpoint(output(),state.channel);sendNow(output(),state.channel,[[0xb0,cc,value]]);}return;
 }
 if($('clock').checked&&armed&&[0xf8,0xfa,0xfb,0xfc].includes(data[0])){try{output()?.send([data[0]]);}catch{setArmed(false);}return;}
 if(!$('thru').checked||!armed)return;
 if((type===0x90||type===0x80)&&data.length>=3){const id=`in:${input.id}:${ch}:${data[1]}`;if(type===0x80||data[2]===0)noteOff(id,data[2]);else noteOn(id,data[1],data[2]);}
 else if(type===0xe0&&data.length>=3)sendNow(output(),state.channel,[[0xe0,data[1],data[2]]]);
 else if(type===0xd0&&data.length>=2)sendNow(output(),state.channel,[[0xd0,data[1]]]);
 else if(type===0xa0&&data.length>=3)sendNow(output(),state.channel,[[0xa0,data[1],data[2]]]);
}
function noteOn(id,note,velocity){if(!armed||!output())return;noteOff(id);const port=output(),channel=state.channel;const shared=[...held.values()].some(x=>x.port===port&&x.channel===channel&&x.note===note);if(shared||sendNow(port,channel,[[0x90,note,Math.max(1,Math.min(127,velocity))]])){held.set(id,{port,channel,note});rememberEndpoint(port,channel);}}
function noteOff(id,velocity=0){const h=held.get(id);if(!h)return;held.delete(id);if(![...held.values()].some(x=>x.port===h.port&&x.channel===h.channel&&x.note===h.note))sendNow(h.port,h.channel,[[0x80,h.note,velocity]]);}
function keyboard(){releaseNotes();$('keys').replaceChildren();$('octaveLabel').textContent=`C${octave}`;const whites=[];for(let i=0;i<48;i++)if(![1,3,6,8,10].includes(i%12))whites.push(i);for(let i=0;i<48;i++){const black=[1,3,6,8,10].includes(i%12),note=12*(octave+1)+i;if(note>127)continue;const before=whites.filter(w=>w<i).length;const b=node('button',{class:'key '+(black?'black':'white'),'aria-label':`Note ${note}`,type:'button'});b.style.width=(black?65/whites.length:100/whites.length)+'%';b.style.left=((black?before-.325:before)*100/whites.length)+'%';if(i%12===0)b.append(node('span',{},`C${octave+Math.floor(i/12)}`));b.onpointerdown=e=>{e.preventDefault();b.setPointerCapture(e.pointerId);noteOn('ptr:'+e.pointerId,note,Math.max(1,Math.min(127,Number($('velocity').value)||90)));if(armed)b.classList.add('held');};const off=e=>{noteOff('ptr:'+e.pointerId);b.classList.remove('held');};b.onpointerup=off;b.onpointercancel=off;b.onlostpointercapture=off;b.onkeydown=e=>{if((e.key===' '||e.key==='Enter')&&!e.repeat){e.preventDefault();noteOn('key:'+note,note,Number($('velocity').value)||90);b.classList.add('held');}};b.onkeyup=e=>{if(e.key===' '||e.key==='Enter'){noteOff('key:'+note);b.classList.remove('held');}};b.onblur=()=>{noteOff('key:'+note);b.classList.remove('held');};$('keys').append(b);}}
for(const [i,[group,label]]of groups.entries()){const b=button('',null,()=>{state.group=group;render();},label);b.dataset.group=group;b.append(node('span',{class:'num'},String(i+1).padStart(2,'0')),document.createTextNode(label));$('navigation').append(b);}
for(let i=0;i<16;i++)$('channel').append(node('option',{value:i},i+1));
$('connect').onclick=connect;$('outputPort').onchange=endpointChange;$('inputPort').onchange=()=>{learning=null;endpointChange();};$('channel').onchange=()=>{endpointChange();state.channel=Number($('channel').value);};
$('midiActions').onclick=async()=>{if(midiActionsEnabled){midiActionsEnabled=false;$('midiActions').setAttribute('aria-pressed','false');$('midiActions').replaceChildren(node('i',{'data-lucide':'shield-alert'}),document.createTextNode('MIDI actions off'));icons();status('Learned MIDI commands disabled');return;}if(await confirmAction('Enable MIDI action triggers?','Learned commands can start recording or change sample data. A CC high edge triggers its assigned command. Output must also be enabled.')){midiActionsEnabled=true;$('midiActions').setAttribute('aria-pressed','true');$('midiActions').replaceChildren(node('i',{'data-lucide':'shield-check'}),document.createTextNode('MIDI actions on'));icons();status('Learned MIDI command triggers enabled');}};
const showSl=(()=>{try{return /[?&#]remotesl\b/.test(String(globalThis.location?.search||'')+String(globalThis.location?.hash||''))||localStorage.getItem('fzed-input-values')==='sl';}catch{return false;}})();  // FZED.html?remotesl offers the Remote SL choice; once chosen it stays offered
if(!showSl)$('inputValuesSl')?.remove?.();
$('inputValues').value='plain';try{const v=localStorage.getItem('fzed-input-values');if(v==='plain'||v==='fzed'||(v==='sl'&&showSl))$('inputValues').value=v;}catch{}
$('inputValues').onchange=()=>{try{localStorage.setItem('fzed-input-values',$('inputValues').value);}catch{}followPairs.clear();status({plain:'Input values: plain 0-127 (scaled for the FZ)',sl:'Input values: Remote SL FZED templates (set FOLLOW to Follow and forward)'}[$('inputValues').value]??'Input values: FZED messages (passed through)');};
$('followPages').onchange=()=>{if(!$('followPages').checked&&pageFollowTimer!==null){clearTimeout(pageFollowTimer);pageFollowTimer=null;pendingFollowDescriptor=null;}};
$('monitorCopy').onclick=async()=>{try{await navigator.clipboard.writeText($('monitor').textContent);status('Monitor copied');}catch{status('Copy failed: select the text instead');}};
drawFz();
$('manual').onclick=()=>window.open('FZED_MANUAL.html','_blank','noopener');
$('arm').onclick=()=>{if(armed){setArmed(false);status('Output locked');return;}if(!output()){status('Select a MIDI output first');return;}if($('inputPort').value&&$('inputPort').value===$('outputPort').value){status('Input and output are identical · feedback risk');return;}setArmed(true);status('Output enabled · CH'+(state.channel+1));};$('panic').onclick=panic;
$('thru').onchange=releaseNotes;
$('clearLearn').onclick=()=>{learning=null;const visible=current();if(state.group==='fx')visible.push(...profile.controls.filter(d=>d.group==='fx'&&[100,101].includes(d.code)));for(const descriptor of visible){if(isAction(descriptor))for(const [raw]of actionOptions(descriptor))delete state.mappings[mapKey(descriptor,raw)];else delete state.mappings[mapKey(descriptor)];}save();render();};
$('sendPage').onclick=async()=>{const list=current().filter(d=>!isAction(d)&&d.code!==111&&state.values[key(d)]!==undefined);if(!armed||!output()){status('Enable output first');return;}if(!list.length){status('No stored values on this view');return;}if(await confirmAction('Send '+list.length+' values?', 'Only this view is sent. No recording, render, initialise or replacement commands are included.'))for(const d of list)enqueue(encode(d,state.values[key(d)]),d.label,key(d));};
$('export').onclick=()=>{const blob=new Blob([JSON.stringify({format:STORAGE,layout:110,target:profile.target,sourceCore:profile.sourceCore,values:state.values,mappings:state.mappings},null,2)],{type:'application/json'});const url=URL.createObjectURL(blob),a=node('a',{href:url,download:'FZED_settings.json'});a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};
$('import').onclick=()=>$('file').click();$('file').onchange=async()=>{const file=$('file').files[0];if(!file)return;try{if(file.size>1024*1024)throw Error('Settings file too large');const data=validate(JSON.parse(await file.text()));setArmed(false);state.values=data.values;state.mappings=data.mappings;const fx=state.values['cc:112'];state.variants.fx=fx===undefined?-1:fxVariant(fx);save();render();status('Settings opened locally · output locked · no MIDI sent');}catch(e){status('Import refused: '+e.message);}finally{$('file').value='';}};
$('octaveDown').onclick=()=>{octave=Math.max(0,octave-1);keyboard();};$('octaveUp').onclick=()=>{octave=Math.min(5,octave+1);keyboard();};$('keysToggle').onclick=()=>{releaseNotes();$('keys').hidden=!$('keys').hidden;};
window.addEventListener('blur',()=>{cancelQueue();releaseNotes();});window.addEventListener('pagehide',()=>{cancelQueue();releaseNotes();});document.addEventListener('visibilitychange',()=>{if(document.hidden){cancelQueue();releaseNotes();}});window.addEventListener('keydown',e=>{if(e.key==='Escape'&&!$('confirmation').open){learning=null;releaseNotes();document.querySelectorAll('.learning').forEach(x=>x.classList.remove('learning'));}});
window.FZ_EDITOR=Object.freeze({encode,validate,profile,key,parseUserBank,bankEntries,presetSlotBytes,presetIndex,fzEcho,fzLines,fzSt,get userBank(){return userBank;}});
try{const stored=localStorage.getItem(BANK_STORE);userBank=parseUserBank(stored?Uint8Array.from(atob(stored),ch=>ch.charCodeAt(0)):bundledBank());}catch(e){try{userBank=parseUserBank(bundledBank());}catch{userBank=null;}status('Stored bank refused: '+e.message);}
const initialFx=state.values['cc:112'];if(initialFx!==undefined)state.variants.fx=fxVariant(initialFx);render();keyboard();icons();
})();
