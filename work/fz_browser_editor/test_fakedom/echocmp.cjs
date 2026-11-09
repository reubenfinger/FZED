// the editor's FZ SCREEN for each (control, value) the emulator scan sent, in the same context: lines 3 and 4
const fs=require('fs');const {boot}=require('./harness.cjs');
const FXO=[1,5,14,9,10,3,11,12,13,4,7,6,8,2,0];
(async()=>{const h=await boot();const E=h.w.FZ_EDITOR,S=E.fzSt;const out={};
 const reset=()=>Object.assign(S,{psel:0,mux:null,rate:0,len:4,gain:0,trig:64,state:'IDLE ',fx:1,live:false,cap:null});
 for(const f of process.argv.slice(2)){const R=JSON.parse(fs.readFileSync(f,'utf8'));
  for(const [k,r] of Object.entries(R)){out[k]=[];const [g,v]=k.split('/');reset();
   if(g==='fx'&&+v>=0)E.fzEcho(112,Math.floor((FXO.indexOf(+v)*128+64)/15));
   if(g.startsWith('capture'))for(const [c,x] of [[10,88],[11,7],[10,89],[11,127]])E.fzEcho(c,x);
   for(const [raw] of r.res){E.fzLines[3]='';E.fzLines[4]='';for(const [cc,x] of r.seq)E.fzEcho(cc,x===null?raw:x);out[k].push([raw,E.fzLines[3].trim(),E.fzLines[4].trim()]);}}}
 fs.writeFileSync(''+(process.env.RXOUT||'../../fzed/tests/rxout')+'/echo_editor.json',JSON.stringify(out));console.log('echo entries',Object.keys(out).length);process.exit(0);})().catch(e=>{console.error(e);process.exit(1);});
