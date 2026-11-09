const assert=require('assert/strict');const {boot,wait}=require('./harness.cjs');
async function run(){const h=await boot();const {$,sent,recv,d,w}=h;const P=w.FZ_EDITOR.profile.controls;const res=[];
 const out=s=>h.tile(s)?.querySelector('output')?.textContent;const go=async g=>{await wait(700);d.querySelector(`nav [data-group="${g}"]`)?.click();};
 const ck=(n,a,b)=>{assert.deepEqual(a,b,n);res.push(n);};
 const lfo1=P.find(x=>x.code===50),dest2=P.find(x=>x.code===1024);
 // FZED values (default)
 $('followMode').value='display';
 await recv(0xb0,50,3);await wait(320);ck('FZED: CC50 value 3 follows as TRI',[$('pageTitle').textContent,out(1)],['LFO 1','TRI']);
 await go('lfo1');h.tile(1).querySelector('.learn').onclick();await recv(0xb0,50,0);await recv(0xb0,50,4);ck('FZED: learned own CC50 value 4 is SQR',out(1),'SQR');
 await go('lfo2');h.tile(2).querySelector('.learn').onclick();await recv(0xb0,10,1);await recv(0xb0,11,40);
 const maps=Object.values(JSON.parse(w.localStorage.getItem('fz-perf38x-editor-v1')).mappings).map(m=>m.cc);
 ck('FZED: Learn refuses a CC10/11 pair',maps.includes(10)||maps.includes(11),false);
 await recv(0xb0,10,14);await recv(0xb0,11,73);await wait(320);ck('FZED: envelope pair still follows',$('pageTitle').textContent,'Envelope stages');
 await recv(0xb0,10,92);await recv(0xb0,11,10);await wait(320);const a=out(2);await recv(0xb0,11,40);await wait(30);
 ck('FZED: bare CC11 keeps editing the selected parameter',[$("pageTitle").textContent,a!==out(2)],['Mod matrix',true]);
 await recv(0xb0,10,99);await recv(0xb0,11,32);await recv(0xb0,10,119);await recv(0xb0,11,45);await wait(320);ck('FZED: LFO2 DEST 2 macro follows',$('pageTitle').textContent,'LFO 2');
 $('followMode').value='forward';sent.length=0;await recv(0xb0,10,14);await recv(0xb0,11,62);await recv(0xb0,50,2);
 ck('FZED forward: messages pass through unchanged',sent,[[0xb0,10,14],[0xb0,11,62],[0xb0,50,2]]);
 // a plain knob learned onto LFO1 waveform (not its own CC) while in FZED mode is treated as 0-127
 await go('lfo1');h.tile(1).querySelector('.learn').onclick();await recv(0xb0,21,0);sent.length=0;await recv(0xb0,21,100);await wait(40);
 ck('FZED: plain knob learned to waveform scales 0-127',[out(1),sent],[lfo1.values[100],[[0xb0,50,lfo1.wireValues[100]]]]);
 // Plain 0-127
 $('inputValues').value='plain';$('inputValues').onchange();
 sent.length=0;await recv(0xb0,50,100);await wait(320);
 ck('Plain: CC50 100 shows the band and sends the FZED value',[out(1),sent],[lfo1.values[100],[[0xb0,50,lfo1.wireValues[100]]]]);
 await go('lfo2');h.tile(8).querySelector('.learn').onclick();await recv(0xb0,22,0);sent.length=0;await recv(0xb0,22,64);await wait(40);
 ck('Plain: one knob drives LFO2 DEST 2 via the CC10/11 macro',sent,[[0xb0,10,99],[0xb0,11,32],[0xb0,10,119],[0xb0,11,dest2.wireValues[64]]]);
 await go('lfo2');h.tile(2).querySelector('.learn').onclick();await recv(0xb0,11,0);sent.length=0;await recv(0xb0,11,70);await wait(40);
 const dly=P.find(x=>x.group==='lfo2'&&x.slot===2);
 ck('Plain: CC11 can be learned as an ordinary knob',sent,[[0xb0,10,dly.sequence[0][1]],[0xb0,11,dly.wireValues[70]]]);
 sent.length=0;await recv(0xb0,10,14);await wait(20);ck('Plain: unlearned CC10 is not forwarded',sent,[]);
 $('inputValues').value='fzed';$('inputValues').onchange();$('followMode').value='off';$('thru').checked=true;sent.length=0;await recv(0xb0,2,55);await recv(0xb0,11,0);
 ck("Thru passes CC2 but not CC11 (FZED's parameter value)",sent,[[0xb0,2,55]]);
 return res;}
(async()=>{for(let p=1;p<=3;p++){const r=await run();console.log(`pass ${p}: ${r.length} checks passed`);}process.exit(0);})().catch(e=>{console.error(e.stack);process.exit(1);});
