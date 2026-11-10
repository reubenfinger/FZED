// FZED for PERF40N / Gills Core 108: new pages (Stretch, Slices, Bank builder), held-step selects, PERF commands,
// multiplexed (parameter 88 / 89) follow
const assert=require('assert/strict');const {boot,wait}=require('./harness.cjs');
async function run(pass){const h=await boot();const {$,sent,recv,d,w}=h;const checks=[];
 const check=(name,actual,expected)=>{assert.deepEqual(actual,expected,`pass ${pass}: ${name}`);checks.push(name);};
 const page=()=>$('pageTitle').textContent;
 const go=g=>{d.querySelector(`[data-group="${g}"]`).click();};
 const confirm=async()=>{await wait(2);const dlg=$('confirmation');dlg.returnValue='confirm';dlg.open=false;dlg.dispatchEvent({type:'close'});await wait(40);};
 const labels=()=>[...$('controls').querySelectorAll('.control')].map(t=>t.querySelector('h3').textContent);
 const nav=[...$('navigation').children].map(b=>b.dataset.group);
 check('pages',nav,['voice','adsr','envelope','lfo1','lfo2','velocity','controllers','matrix','loop','stretch','record','capture','chop','slices','fx','bank','user']);
 go('voice');check('voice page keeps no bank controls',labels(),['DCF CUTOFF','DCQ RESONANCE','TAPE SPEED','ORIGINAL KEY','LOWEST KEY','HIGHEST KEY']);
 check('LFO 2 top row follows the Gills (rate, shape, delay, fade-in, mode)',(go('lfo2'),[0,1,2,3,4].map(i=>h.tile(i).querySelector('h3').textContent)),['LFO2 RATE DIV','LFO2 SHAPE','LFO2 DELAY','LFO2 FADE-IN','LFO2 MODE']);go('voice');
 check('voice page groups',[...$('controls').querySelectorAll('.group-label')].map(x=>x.textContent),['Filter','Speed','Keys']);
 go('bank');check('bank builder controls in build order',labels(),['VOICE PICK','VOICE SELECT','NEW VOICE','COPY VOICE','BANK SELECT','BANK ADD/CLEAR','CHOP INTO','FREEZE CHOP']);
 check('bank builder explains the sequence',$('subviews').children.some(c=>c.className==='bank-guide'),true);
 go('stretch');const time=h.tile(1).querySelector('.knob');
 check('STRETCH TIME is a 32-step pot',time.getAttribute('aria-valuemax'),'31');
 time.stepTo(0);await wait(20);const first=h.tile(1).querySelector('output').textContent;time.stepTo(31);await wait(20);
 check('first and last hold',[first,h.tile(1).querySelector('output').textContent],['HOLD 0.02 S','HOLD 19.5 S']);
 sent.length=0;time.stepTo(11);await wait(30);
 check('STRETCH TIME sends 88 / 1 / 89 / value',sent,[[0xb0,10,88],[0xb0,11,1],[0xb0,10,89],[0xb0,11,29]]);
 check('ORDER has 11 steps',h.tile(7).querySelector('.knob').getAttribute('aria-valuemax'),'10');
 h.tile(0).querySelector('.knob').stepTo(0);await wait(30);  // 2 segments
 check('SUSTAIN AT follows the segment count',h.tile(5).querySelector('.knob').getAttribute('aria-valuemax'),'2');
 { const k=h.tile(5).querySelector('.knob'),names=[];for(let i=0;i<=2;i++){k.stepTo(i);await wait(10);names.push(k.getAttribute('aria-valuetext'));}
   check('SUSTAIN AT names at 2 segments',names,['NO SUSTAIN','HOLD SEGMENT 1','HOLD SEGMENT 2']); }
 h.tile(0).querySelector('.knob').stepTo(6);await wait(30);  // 8 segments
 { const k=h.tile(5).querySelector('.knob'),names=[];for(let i=0;i<=8;i++){k.stepTo(i);await wait(10);names.push(k.getAttribute('aria-valuetext'));}
   check('SUSTAIN AT names at 8 segments',names,['NO SUSTAIN',...[1,2,3,4,5,6,7,8].map(i=>'HOLD SEGMENT '+i)]); }
 const sw=h.tile(9).querySelector('.switch');check('STRETCH ON/OFF is a two-way switch',sw.children.map(b=>b.textAll),['OFF (OWN LOOPS)','STRETCH ON']);
 sent.length=0;sw.children[1].click();await wait(30);check('switch sends ON',sent.at(-1),[0xb0,11,96]);
 check('switch shows ON',sw.children.map(b=>b.getAttribute('aria-pressed')),['false','true']);
 go('voice');$('followMode').value='display';await recv(0xb0,10,88);await recv(0xb0,11,17);await recv(0xb0,10,89);await recv(0xb0,11,48);await wait(330);
 check('88 / 89 follow switches to Stretch',page(),'Stretch');
 check('followed ORDER value',h.tile(7).querySelector('output').textContent,'REVERSE');
 $('followMode').value='off';
 go('record');const exitTile=h.tile(9);const keepAll=exitTile.querySelectorAll('.action-row')[3].children[0];
 check('EXIT FZED choices',[...exitTile.querySelectorAll('.action-row')].map(r=>r.children[0].textAll),['Discard (ESC)','Keep sound (ENTER)','Keep all of edit voice (ENTER)','Keep all (ENTER)']);
 sent.length=0;keepAll.click();await confirm();
 check('KEEP ALL sends control 14 = 127 then control 13 = 127',sent,[[0xb0,10,88],[0xb0,11,14],[0xb0,10,89],[0xb0,11,127],[0xb0,10,88],[0xb0,11,13],[0xb0,10,89],[0xb0,11,127]]);
 go('capture');const enter=[...$('controls').querySelectorAll('.control')].find(t=>t.querySelector('h3').textContent==='CAPTURE ON/OFF').querySelectorAll('.action-row')[1].children[0];
 sent.length=0;enter.click();await confirm();
 check('Enter capture sends PERF control 7',sent,[[0xb0,10,88],[0xb0,11,7],[0xb0,10,89],[0xb0,11,127]]);
 go('bank');sent.length=0;h.tile(3).querySelector('.action-row').children[0].click();await confirm();
 check('COPY VOICE re-arms then copies',sent,[[0xb0,10,126],[0xb0,11,0],[0xb0,10,126],[0xb0,11,127]]);
 sent.length=0;h.tile(7).querySelector('.action-row').children[0].click();await confirm();
 check('FREEZE sends control 15',sent,[[0xb0,10,88],[0xb0,11,15],[0xb0,10,89],[0xb0,11,127]]);
 sent.length=0;h.tile(6).querySelector('.switch').children[1].click();await wait(30);
 check('CHOP INTO TARGET sends control 6',sent,[[0xb0,10,88],[0xb0,11,6],[0xb0,10,89],[0xb0,11,96]]);
 go('slices');check('slices page',labels().sort(),['SLICE','SLICE MOVE','SLICE LOWEST','SLICE HIGHEST','SLICE OUTPUT','OUTPUT (CHOKE)','FILTER/ENV/LFO1','LOOP MODE','COPY VOICE'].sort());
 const mv=h.tile(1).querySelector('.knob');mv.stepTo(0);await wait(20);check('SLICE MOVE has 48 notes from C-1',[mv.getAttribute('aria-valuemax'),h.tile(1).querySelector('output').textContent],['47','C-1']);
 check('no Gills-only controls in the profile',w.FZ_EDITOR.profile.controls.filter(x=>[1280,1281,1283,1284,1285].includes(x.code)).length,0);
 // Core 110 moved pots: Learn assignments saved before it follow their control
 {const old={format:'fz-perf38x-editor-v1',values:{},mappings:{'voice:5':{input:'in',channel:0,cc:20},'lfo2:5':{input:'in',channel:0,cc:21},'adsr:3':{input:'in',channel:0,cc:22}}};
  const h2=await boot({storage:{'fz-perf38x-editor-v1':JSON.stringify(old)}});const learned=g=>{h2.d.querySelector(`[data-group="${g}"]`).click();return [...h2.$('controls').querySelectorAll('.control')].filter(t=>t.querySelector('.control-meta').children.some(c=>(c.textContent||'').startsWith('Learn'))).map(t=>t.querySelector('h3').textContent);};
  check('older Learn on HIGHEST KEY still on HIGHEST KEY',learned('voice'),['HIGHEST KEY']);
  check('older Learn on LFO2 DELAY still on LFO2 DELAY',learned('lfo2'),['LFO2 DELAY']);
  check('unmoved page keeps its Learn',learned('adsr'),['DCA RELEASE']);}
 return checks.length;}
(async()=>{for(let p=1;p<=3;p++)console.log('pages40 pass',p,await run(p),'checks');process.exit(0);})().catch(e=>{console.error(e.message);process.exit(1);});
