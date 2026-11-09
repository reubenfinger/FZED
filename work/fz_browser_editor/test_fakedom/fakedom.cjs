// Minimal DOM stand-in, enough to run the FZED editor's logic in node (no jsdom available here).
class CL{constructor(e){this.e=e;}get s(){return new Set((this.e.className||'').split(/\s+/).filter(Boolean));}
 add(...c){const s=this.s;c.forEach(x=>s.add(x));this.e.className=[...s].join(' ');}remove(...c){const s=this.s;c.forEach(x=>s.delete(x));this.e.className=[...s].join(' ');}
 toggle(c,f){const s=this.s;const on=f===undefined?!s.has(c):!!f;on?s.add(c):s.delete(c);this.e.className=[...s].join(' ');return on;}contains(c){return this.s.has(c);}}
class El{constructor(tag){this.tagName=tag.toUpperCase();this.children=[];this.attrs={};this._value='';this.checked=false;this.textContent='';this.className='';this.classList=new CL(this);const self=this;this.dataset=new Proxy({},{set(o,k,v){o[k]=String(v);self.attrs['data-'+String(k).replace(/[A-Z]/g,c=>'-'+c.toLowerCase())]=String(v);return true;}});this.style={};this.hidden=false;this.disabled=false;this.open=false;this.returnValue='';this.listeners={};}
 get value(){if(this.tagName==='SELECT'&&this._value===''&&this.children.length&&this._sel===undefined)return this.children.find(o=>o.tagName==='OPTION')?.value??'';return this._value;}
 set value(v){this._value=String(v);this._sel=1;}
 get options(){return this.children.filter(c=>c.tagName==='OPTION');}
 setAttribute(k,v){this.attrs[k]=String(v);if(k==='value')this._value=String(v);if(k.startsWith('data-'))this.dataset[k.slice(5).replace(/-(.)/g,(_,c)=>c.toUpperCase())]=String(v);if(k==='class')this.className=String(v);if(k==='type')this.type=String(v);if(k==='id')El.ids[v]=this;}
 getAttribute(k){return this.attrs[k]??null;}
 append(...n){for(const x of n){if(typeof x==='string'){const t=new El('#text');t.textContent=x;this.children.push(t);}else this.children.push(x);}}
 appendChild(x){this.append(x);return x;}
 replaceChildren(...n){this.children=[];this.append(...n);}
 addEventListener(t,f){(this.listeners[t]=this.listeners[t]||[]).push(f);}
 dispatchEvent(e){(this.listeners[e.type]||[]).forEach(f=>f(e));const h=this['on'+e.type];if(h)h(e);}
 click(){this.dispatchEvent({type:'click'});}
 showModal(){this.open=true;}close(){this.open=false;}
 getContext(){return new Proxy({},{get:()=>()=>{}});}
 focus(){}remove(){this.removed=true;}
 all(){const out=[];const w=n=>{for(const c of n.children){out.push(c);w(c);}};w(this);return out;}
 matches(sel){return sel.split(',').some(s=>El.m(this,s.trim()));}
 querySelector(sel){return this.all().find(e=>e.matches(sel))??null;}
 querySelectorAll(sel){return this.all().filter(e=>e.matches(sel));}
 get textAll(){return this.textContent+this.children.map(c=>c.textAll).join('');}
}
El.ids={};
El.m=(e,s)=>{const parts=s.split(/\s+/);const last=parts[parts.length-1];
 const re=/^([a-z0-9]*)((?:\[[^\]]+\]|\.[\w-]+)*)$/i;const mm=last.match(re);if(!mm)return false;
 if(mm[1]&&e.tagName!==mm[1].toUpperCase())return false;
 for(const a of mm[2].match(/\[[^\]]+\]|\.[\w-]+/g)||[]){if(a[0]==='.'){if(!e.classList.contains(a.slice(1)))return false;}else{const [k,v]=a.slice(1,-1).split('=');const val=v===undefined?undefined:v.replace(/^"|"$/g,'');const have=k==='type'?(e.type??e.attrs.type):e.attrs[k];if(val===undefined?have===undefined:have!==val)return false;}}
 return true;};
function makeWindow(){
 El.ids={};const doc={getElementById:id=>El.ids[id]||(El.ids[id]=Object.assign(new El(id==='inputPort'||id==='outputPort'||id==='followMode'||id==='channel'||id==='inputValues'?'select':'div'),{id})),
  createElement:t=>new El(t),createTextNode:t=>{const e=new El('#text');e.textContent=t;return e;},
  querySelector:s=>Object.values(El.ids).map(e=>e.matches(s)?e:e.querySelector(s)).find(Boolean)??null,
  querySelectorAll:s=>{const r=[];for(const e of Object.values(El.ids)){if(e.matches(s))r.push(e);r.push(...e.querySelectorAll(s));}return [...new Set(r)];},
  addEventListener(){},body:new El('body'),hidden:false};
 const store={};
 const w={document:doc,localStorage:{getItem:k=>store[k]??null,setItem:(k,v)=>{store[k]=v;}},navigator:{},performance:{now:()=>Date.now()},addEventListener(){},
  setTimeout,clearTimeout,console,URL:{createObjectURL:()=>'blob:',revokeObjectURL(){}},Blob:class{},FileReader:class{},matchMedia:()=>({matches:false,addEventListener(){}})};
 w.window=w;return w;}
module.exports={El,makeWindow};
