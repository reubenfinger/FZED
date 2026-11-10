// Input choices for FZED users: plain 0-127 by default, Remote SL only with ?remotesl, All inputs (but not the FZ's own port)
const assert=require('assert/strict');const {boot,wait}=require('./harness.cjs');
(async()=>{let n=0;const ck=(name,a,e)=>{assert.deepEqual(a,e,name);n++;};
 let h=await boot({keepDefault:true});
 ck('plain 0-127 is the default',h.defaults.input,'plain');ck('Remote SL is hidden',h.defaults.slHidden,true);
 const opts=h.$('inputPort').children.map?h.$('inputPort').children.map(o=>o.value):[...h.$('inputPort').children].map(o=>o.value);
 ck('IN offers All inputs',opts.includes('*'),true);
 h.$('followMode').value='display';h.$('inputPort').value='*';
 await h.recv(0xb0,50,127);await wait(320);ck('All inputs: a controller is followed (plain: 127 = last LFO 1 waveform)',h.$('pageTitle').textContent,'LFO 1');
 h.$('pageTitle').textContent='';await h.recvLoop(0xb0,74,10);await wait(320);ck('All inputs: the FZ interface\'s own port is ignored',h.$('pageTitle').textContent,'');
 h.$('inputPort').value='in';h.$('arm').onclick();ck('output locked',h.$('arm').getAttribute('aria-pressed'),'false');
 h.$('followMode').value='forward';await h.recv(0xb0,74,40);await wait(320);ck('a control moved while locked says so and flashes the button',[h.$('status').textContent,h.$('arm').classList.contains('nudge')],['Output is locked · press Output locked to send',true]);
 h=await boot({keepDefault:true,search:'?remotesl'});ck('?remotesl offers Remote SL',h.defaults.slHidden,false);
 console.log('inputs',n,'checks');process.exit(0);})().catch(e=>{console.error(e);process.exit(1);});
