// the FZ screen follows mouse changes with output locked and no MIDI input
const assert=require('assert/strict');const {boot,wait}=require('./harness.cjs');
(async()=>{const h=await boot();const {$,d}=h;
 $('arm').onclick?.();await wait(5);$('inputPort').value='';
 d.querySelector('[data-group="chop"]').click();await wait(5);
 const tile=[...$('controls').querySelectorAll('.control')].find(x=>x.querySelector('h3').textContent==='CHOP SLICE COUNT');
 tile.querySelector('.knob').stepTo(2);await wait(20);
 assert.equal(h.w.FZ_EDITOR.fzLines[3].trim(),'CHOP 16 SLICES');
 d.querySelector('[data-group="record"]').click();await wait(5);
 const rate=[...$('controls').querySelectorAll('.control')].find(x=>x.querySelector('h3').textContent==='RECORD RATE');
 rate.querySelector('.knob').stepTo(1);await wait(20);
 assert.equal(h.w.FZ_EDITOR.fzLines[5].slice(0,8),'REC 18K ');
 d.querySelector('[data-group="chop"]').click();await wait(5);
 const E=h.w.FZ_EDITOR;assert.equal(E.fzLines[0],'FZED');E.fzEcho(98,0);E.fzEcho(98,127);
 assert.deepEqual([E.fzLines[3].trim(),E.fzLines[4]],['CHOPPING...','C=098 127']);
 E.fzEcho(98,64);assert.deepEqual([E.fzLines[3].trim(),E.fzLines[4]],['> PLAY SLICES','C=098 064']);
 E.fzEcho(98,0);assert.equal(E.fzLines[3].trim(),'> PLAY VOICE');
 E.fzEcho(99,80);assert.deepEqual([E.fzLines[3].trim(),E.fzLines[4]],['CHOP 16 SLICES','C=099 080']);
 E.fzEcho(74,37);assert.deepEqual([E.fzLines[3].trim(),E.fzLines[4]],['CHOP 16 SLICES','C=074 037']);   // echo only: line 3 stays
 E.fzEcho(10,62);E.fzEcho(11,37);assert.equal(E.fzLines[4],'P=062 037');
 // values FZED's emulator drew (lcdcmp.py): paced messages, no echo
 E.fzEcho(112,8);assert.equal(E.fzLines[3].trim(),'FX TAPEHACK');E.fzEcho(115,37);assert.equal(E.fzLines[3].trim(),'INPUT x02.9');
 E.fzEcho(112,46);E.fzEcho(113,54);assert.equal(E.fzLines[3].trim(),'BITS 04');
 E.fzEcho(112,81);E.fzEcho(94,64);assert.equal(E.fzLines[3].trim(),'RING 0021.3HZ');
 E.fzEcho(112,98);E.fzEcho(95,37);assert.equal(E.fzLines[3].trim(),'KS FDBK 029%');
 E.fzLines[4]='';E.fzEcho(117,64);assert.deepEqual([E.fzLines[3].trim(),E.fzLines[4]],['MIX 050%','']);
 for(const [c,x] of [[10,88],[11,7],[10,89],[11,127]])E.fzEcho(c,x);assert.equal(E.fzLines[3].trim(),'C0010 x4 +00 F');
 E.fzEcho(23,37);assert.equal(E.fzLines[3].trim(),'C0010 x4 -10 F');E.fzEcho(33,24);assert.equal(E.fzLines[3].trim(),'C0010 x4 -10 S');
 E.fzEcho(96,35);assert.equal(E.fzLines[3].trim(),'5+8  SAM 0000MS');E.fzEcho(34,24);assert.equal(E.fzLines[3].trim(),'FADE 0050MS');
 E.fzLines[4]='';E.fzEcho(86,21);assert.deepEqual([E.fzLines[3].trim(),E.fzLines[4]],['ONE-SHOT','']);E.fzEcho(86,106);assert.equal(E.fzLines[3].trim(),'LOOP');
 E.fzEcho(70,48);assert.equal(E.fzLines[3].trim(),'REVERSE');E.fzEcho(70,100);assert.equal(E.fzLines[3].trim(),'CUE');
 E.fzEcho(108,32);assert.deepEqual([E.fzLines[3].trim(),E.fzLines[4]],['CAPTURE OFF','C=108 032']);
 console.log('fzscreen 25 checks');process.exit(0);})().catch(e=>{console.error(e.message);process.exit(1);});
