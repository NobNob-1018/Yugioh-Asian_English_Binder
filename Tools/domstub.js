// minimal DOM so the app's boot path can run headless
class El{
  constructor(tag){this.tagName=(tag||'div').toUpperCase();this.children=[];this._html='';this.style={setProperty(){},cssText:''};
    this.classList={_s:new Set(),add(c){this._s.add(c)},remove(c){this._s.delete(c)},toggle(c,v){v?this._s.add(c):this._s.delete(c)},contains(c){return this._s.has(c)}};
    this.dataset={};this.value='';this.textContent='';this.className='';this.disabled=false;}
  set innerHTML(v){this._html=String(v);this.children=[];}
  get innerHTML(){return this._html;}
  appendChild(c){this.children.push(c);return c;}
  setAttribute(){}getContext(){return{drawImage(){},getImageData(){return{data:[]}},putImageData(){}}}
  querySelector(){return new El('div');}
  querySelectorAll(){return [];}
  remove(){}focus(){}click(){}
  addEventListener(){}
}
const reg={};
global.document={
  createElement:t=>new El(t),
  querySelector:s=>reg[s]||(reg[s]=new El('div')),
  querySelectorAll:()=>[],
  getElementById:id=>reg['#'+id]||(reg['#'+id]=new El('div')),
  addEventListener(){},
  head:new El('head'), body:new El('body'),
  documentElement:new El('html')
};
global.window={isSecureContext:true};
global.navigator={clipboard:null};
global.localStorage={_d:{},getItem(k){return this._d[k]||null},setItem(k,v){this._d[k]=v}};
global.URL={createObjectURL:()=>'blob:x',revokeObjectURL(){}};
global.reg=reg;
module.exports={El,reg};
