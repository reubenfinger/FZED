// Remote SL input mode: channel 16 CCs and NRPN from the FZED ReMOTE SL templates
const assert=require('assert/strict');const {boot,wait}=require('./harness.cjs');
async function run(pass){const h=await boot();const {$,sent,recv,d}=h;const checks=[];
 const check=(name,a,e)=>{assert.deepEqual(JSON.parse(JSON.stringify(a)),e,`pass ${pass}: ${name}`);checks.push(name);};
 $('inputValues').value='sl';$('inputValues').onchange();$('followMode').value='forward';
 const sl=async(cc,v)=>{await recv(0xb0,cc,v);};  // the SL sends on channel 1 (seen on hardware)
 const nr=async(msb,lsb,v)=>{await sl(99,msb);await sl(98,lsb);await sl(6,v);};  // as the SL sends it
 const out=async()=>{await wait(80);const x=sent.splice(0);return x;};
 AT0=h.w.FZ_EDITOR.profile.controls.find(d=>d.group==='controllers'&&d.variant===2&&d.slot===0).sequence[0][1];
 sent.length=0;await sl(74,100);check('SL CC goes to the FZ channel',await out(),[[0xb0,74,100]]);
 check('and is followed on the editor',h.tile(0).querySelector('output').textContent!=='—'&&h.tile(0).querySelector('output').textContent!=='',true);
 await nr(0,1,50);check('NRPN 0/1 = LFO2 DELAY (CC10 1, CC11 value)',await out(),[[0xb0,10,1],[0xb0,11,50]]);
 await nr(1,1,40);check('NRPN 1/1 = STRETCH TIME (88 / 89)',await out(),[[0xb0,10,88],[0xb0,11,1],[0xb0,10,89],[0xb0,11,40]]);
 await nr(2,1,2);await wait(20);check('NRPN 2/1 picks envelope step 3',[$('pageTitle').textContent,[...$('subviews').children].find(b=>b.getAttribute&&b.getAttribute('aria-pressed')==='true')?.textAll],['Envelope stages','Step 3']);
 await nr(3,0,40);check('NRPN 3/0 = AMP RATE of the selected step (param 16)',await out(),[[0xb0,10,16],[0xb0,11,40]]);
 await nr(2,2,2);await nr(4,0,30);check('NRPN 4/0 = LFO pitch of the selected source (aftertouch)',await out(),[[0xb0,10,AT0],[0xb0,11,30]]);
 await nr(2,3,2);await nr(5,1,90);check('NRPN 5/1 = AMOUNT of matrix route 3 (param 102)',await out(),[[0xb0,10,102],[0xb0,11,90]]);
 await sl(112,80);await out();await nr(6,3,70);check('NRPN 6/3 = FX P4 of RING MOD (CC94)',await out(),[[0xb0,94,70]]);
 await nr(7,98,127);await wait(200);check('MAKE SLICES re-arms, waits 150 ms, then creates',await out(),[[0xb0,98,0],[0xb0,98,127]]);
 await nr(2,4,3);check('EXIT ALL',await out(),[[0xb0,10,88],[0xb0,11,14],[0xb0,10,89],[0xb0,11,127],[0xb0,10,88],[0xb0,11,13],[0xb0,10,89],[0xb0,11,127]]);
 await nr(2,8,127);check('CAPTURE ON is PERF control 7',await out(),[[0xb0,10,88],[0xb0,11,7],[0xb0,10,89],[0xb0,11,127]]);
 await sl(106,127);await sl(106,0);check('REC ARM press and release both sent',await out(),[[0xb0,106,127],[0xb0,106,0]]);
 const before=$('pageTitle').textContent;await nr(2,0,127);await wait(20);check('PAGE > moves the editor page',$('pageTitle').textContent!==before,true);
 await sl(108,0);await out();check('leaving capture shows CAPTURE OFF',h.w.FZ_EDITOR.fzLines[3].trim(),'CAPTURE OFF');
 await nr(7,97,64);check('CHOP MODE button (NRPN 7/97) sends CC97',await out(),[[0xb0,97,64]]);
 check('FZ screen shows PERF\'s chop mode message',h.w.FZ_EDITOR.fzLines[3],'CHOP EVEN+ZERO ');
 await sl(15,0);await sl(15,64);await out();check('BANK ADD shows VOICE ADDED (release re-arms quietly)',h.w.FZ_EDITOR.fzLines[3].trim(),'VOICE ADDED');
 await sl(15,127);await out();check('BANK CLR shows CH01 CLEARED',h.w.FZ_EDITOR.fzLines[3].trim(),'CH01 CLEARED');
 await sl(103,20);await out();check('FZ screen record line',h.w.FZ_EDITOR.fzLines[5],'REC 36K  002.1S');
 await nr(0,1,50);await out();check('FZ screen echoes a parameter as P= (line 4, as FZED)',h.w.FZ_EDITOR.fzLines[4].trim(),'P=001 050');
 await nr(0,8,35);check('PATTERN button (NRPN 0/8) sends parameter 8',await out(),[[0xb0,10,8],[0xb0,11,35]]);
 await sl(1,0);await sl(1,1);await sl(1,2);await sl(6,24);await sl(1,2);await sl(6,30);await out();await sl(99,1);await sl(98,2);await sl(6,36);check('GRAIN as captured on the SL (CC99 1, CC98 2, CC6 36)',await out(),[[0xb0,10,88],[0xb0,11,2],[0xb0,10,89],[0xb0,11,36]]);
 await sl(101,127);await sl(100,127);check('RPN null is not passed on as DELETE UNUSED / NORMALISE',await out(),[]);
 $('followMode').value='display';await sl(75,20);check('display only: nothing sent',await out(),[]);
 await sl(102,40);await sl(106,127);check('display only: the FZ screen still follows the SL (rate, armed)',[h.w.FZ_EDITOR.fzLines[5].slice(0,8),h.w.FZ_EDITOR.fzLines[6].slice(0,5)],['REC 18K ','ARMED']);
 $('inputValues').value='fzed';$('inputValues').onchange();await recv(0xb0,99,100);check('FZED input: incoming CC shows on the FZ screen',h.w.FZ_EDITOR.fzLines[3],'CHOP 32 SLICES ');
 return checks.length;}
let AT0;
(async()=>{for(let p=1;p<=3;p++)console.log('remotesl pass',p,await run(p),'checks');process.exit(0);})().catch(e=>{console.error(e.message);process.exit(1);});
