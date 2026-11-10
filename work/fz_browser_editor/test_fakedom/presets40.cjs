// FZED user presets: page presets in the bundled bank, save / rename / delete, stretch values in bytes 530-541 (Core 109)
const assert=require('assert/strict');const {boot,wait}=require('./harness.cjs');
async function run(pass){const h=await boot();const {$,sent,d,w}=h;const checks=[];
 const check=(name,actual,expected)=>{assert.deepEqual(JSON.parse(JSON.stringify(actual)),expected,`pass ${pass}: ${name}`);checks.push(name);};
 const go=g=>d.querySelector(`[data-group="${g}"]`).click();const E=w.FZ_EDITOR;
 const bar=()=>$('subviews').children.find(c=>c.className==='preset-bar');
 const barNames=()=>{const sel=bar().querySelector('select');return sel?sel.children.slice(1).map(o=>o.textContent):[];};
 const dialog=async(fields)=>{await wait(2);for(const [id,v]of Object.entries(fields))$(id).value=v;const dl=$('presetDialog');dl.returnValue='save';dl.open=false;dl.onclose();await wait(20);};
 const confirm=async()=>{await wait(2);const dl=$('confirmation');dl.returnValue='confirm';dl.open=false;dl.dispatchEvent({type:'close'});await wait(30);};
 check('bundled bank: 26 Gills presets + 21 page presets',E.userBank.presets.length,47);
 go('stretch');check('stretch page presets',barNames(),['ST TIMESTRCH','ST REVERSE','ST SHUFFLE','ST STUTTER','ST SLOWDOWN','ST FREEZE','ST PINGPONG']);
 go('fx');check('FX page lists its presets',barNames().includes('FX TAPEDRIVE')&&!barNames().includes('ST REVERSE'),true);
 go('chop');check('pattern presets on Chop / Pattern',barNames().filter(n=>n.startsWith('PT ')).length,5);
 go('lfo1');check('LFO 1 presets',barNames(),['LF VIBRATO','LF TREMOLO','LF WOBBLE']);
 // open a stretch preset locally
 go('stretch');const sel=bar().querySelector('select');sel.value=String(E.userBank.presets.find(p=>p.name==='ST REVERSE').slot);
 const before=h.sent.length;bar().children.find(b=>b.textAll==='Open').click();await wait(20);
 check('Open sends nothing',h.sent.length,before);check('Open leaves output enabled',h.$('arm').getAttribute('aria-pressed'),'true');
 check('opened: order REVERSE, next SKIP CUT',[h.tile(7).querySelector('output').textContent,h.tile(6).querySelector('output').textContent],['REVERSE','SKIP, CUT LEAD-IN']);
 // send it: stretch values as 88 / 89 pairs, ON last
 const rev=E.userBank.presets.find(p=>p.name==='ST REVERSE');const ents=E.bankEntries(rev);
 check('stretch entries in Gills order, ON last',ents.map(e=>e.ext),[0,1,2,3,4,5,6,7,8,9]);
 check('ORDER entry sends control 17',ents.find(e=>e.ext===7).packets,[[10,88],[11,17],[10,89],[11,rev.ext[7]]]);
 // save this page as a new preset
 h.tile(1).querySelector('.knob').stepTo(20);await wait(20);
 bar().children.find(b=>b.textAll==='Save as preset…').click();await dialog({presetName:'my stretch',presetSlot:'90',presetScope:'page'});
 const mine=E.userBank.presets.find(p=>p.slot===90);
 check('saved name in capitals',mine.name,'MY STRETCH');
 check('page preset: stretch only (no CC / parameter values)',[mine.known,mine.values.every(v=>v===255)],[0,true]);
 check('stretch time stored',mine.ext[1],E.profile.controls.find(c=>c.code===1537).steps[20]);
 const bytes=E.userBank.bytes;check('slot bytes: device 4, used, S marker',[bytes[16+89*544+12],bytes[16+89*544+13],bytes[16+89*544+530]],[4,1,0x53]);
 check('new preset listed on the page',barNames().includes('MY STRETCH'),true);
 // whole voice
 go('voice');h.tile(0).querySelector('input[type=range]').value='99';h.tile(0).querySelector('input[type=range]').oninput();await wait(10);
 bar().children.find(b=>b.textAll==='Save as preset…').click();await dialog({presetName:'WHOLE',presetSlot:'91',presetScope:'all'});
 const whole=E.userBank.presets.find(p=>p.slot===91);
 check('whole voice: cutoff CC74 and the stretch values',[whole.values[74],whole.ext[1]!==255],[99,true]);
 check('whole voice preset not listed on a single page',barNames().includes('WHOLE'),false);
 // FX page preset keeps only FX
 go('fx');{const sl=bar().querySelector('select');sl.value=String(E.userBank.presets.find(p=>p.name==='FX TAPEDRIVE').slot);bar().children.find(b=>b.textAll==='Open').click();await wait(20);}
 bar().children.find(b=>b.textAll==='Save as preset…').click();await dialog({presetName:'FX ONLY',presetSlot:'92',presetScope:'page'});
 check('FX page preset copies TapeHack drive',[E.userBank.presets.find(p=>p.slot===92)?.values[112],E.userBank.presets.find(p=>p.slot===92)?.values[115]],[4,64]);
 const fxp=E.userBank.presets.find(p=>p.slot===92);
 check('FX page preset holds no cutoff or stretch',[fxp?.values[74],fxp?.ext.every(v=>v===255)],[255,true]);
 // rename / delete on the User presets page
 go('user');const tile=[...$('controls').children].find(t=>t.querySelector('h3').textContent.endsWith('MY STRETCH'));
 tile.querySelector('.preset-actions').children.find(b=>b.textAll==='Rename').click();await dialog({presetName:'GLASS'});
 check('renamed',E.userBank.presets.find(p=>p.slot===90).name,'GLASS');
 const t2=[...$('controls').children].find(t=>t.querySelector('h3').textContent.endsWith('GLASS'));
 t2.querySelector('.preset-actions').children.find(b=>b.textAll==='Delete').click();await confirm();
 check('deleted',E.userBank.presets.some(p=>p.slot===90),false);
 check('bank kept in browser storage',w.localStorage.getItem('fzed-user-bank-v1').length>70000,true);
 check('bank parses back',E.parseUserBank(E.userBank.bytes).presets.length,E.userBank.presets.length);
 return checks.length;}
(async()=>{for(let p=1;p<=3;p++)console.log('presets40 pass',p,await run(p),'checks');process.exit(0);})().catch(e=>{console.error(e.stack||e.message);process.exit(1);});
