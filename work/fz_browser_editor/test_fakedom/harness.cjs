const fs=require('fs'),path=require('path'),vm=require('vm');const {makeWindow}=require('./fakedom.cjs');
const APP=process.env.APP||path.resolve(__dirname,'../../../outputs/FZED');
const wait=ms=>new Promise(r=>setTimeout(r,ms));
async function boot(opts={}){
 const w=makeWindow();for(const [k,v] of Object.entries(opts.storage??{}))w.localStorage.setItem(k,v);const d=w.document,$=id=>d.getElementById(id);
 const sent=[];const input={id:'in',name:'Ctl',state:'connected',onmidimessage:null};const out={id:'out',name:'FZ',state:'connected',send:x=>sent.push([...x])};const loop={id:'loopin',name:'FZ',state:'connected',onmidimessage:null};
 w.navigator.requestMIDIAccess=async()=>({inputs:new Map([['in',input],['loopin',loop]]),outputs:new Map([['out',out]])});
 for(const id of ['followPages'])$(id).checked=true;
 w.atob=x=>Buffer.from(x,'base64').toString('binary');w.btoa=x=>Buffer.from(x,'binary').toString('base64');w.Uint8Array=Uint8Array;
 if(opts.search)w.location={search:opts.search,hash:''};vm.createContext(w);for(const f of ['profile.js','user-bank.js','editor.js'])vm.runInContext(fs.readFileSync(path.join(APP,f),'utf8'),w,{filename:f});
 await $('connect').onclick();await wait(1);
 const defaults={input:$('inputValues').value,slHidden:!!$('inputValuesSl').removed};if(!opts.keepDefault){$('inputValues').value='fzed';}
 const opt=v=>Object.assign(d.createElement('option'),{});
 $('inputPort').value='in';$('inputPort').onchange?.();$('outputPort').value='out';$('outputPort').onchange?.();$('arm').onclick?.();
 const recv=async(...b)=>{input.onmidimessage({data:new Uint8Array(b)});await wait(12);};const recvLoop=async(...b)=>{loop.onmidimessage({data:new Uint8Array(b)});await wait(12);};
 return {recvLoop,defaults,w,d,$,sent,recv,wait,tile:s=>d.querySelector(`[data-slot="${s}"]`)};
}
module.exports={boot,wait};
