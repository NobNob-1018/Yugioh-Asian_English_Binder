/* ---- service worker ----
   The binder is one big file, and the point of caching it is that after a
   single visit it opens with no network at all: on a phone in a card shop with
   no signal, on a train, with GitHub unreachable. Everything below serves that.

   The shell is stale-while-revalidate. You get the cached copy immediately -
   which is what makes a 1.6 MB file open instantly - and a fresh copy is
   fetched in the background for next time. So an update lands silently on the
   next open rather than making you wait for it on this one.              */
const VERSION='ygo-binder-v25';
const SHELL=VERSION+'-shell';
const IMGS=VERSION+'-img';
const DATA=VERSION+'-data';
/* Card art is small but endless, so the cache keeps a window rather than
   everything. 600 was that window when the pool was smaller; against 5,028
   Asian-English cards it is about eight pages, so paging back and forth
   evicted art you had already downloaded and fetched it again - which is
   most of what "slow on mobile" was.

   A cards_small thumbnail runs 15-25 KB, so 2,400 of them is roughly 50 MB:
   large enough to hold everything you actually browse, small enough that no
   browser will evict the whole origin over it. */
const IMG_CAP=2400;

self.addEventListener('install',e=>{
  e.waitUntil((async()=>{
    const c=await caches.open(SHELL);
    /* './' and './index.html' are the same page on Pages, but a request can
       arrive as either, so both are primed */
    try{ await c.addAll(['./','./index.html','./manifest.webmanifest','./icon.svg']); }
    catch(err){ try{ await c.add('./'); }catch(e2){} }
    self.skipWaiting();
  })());
});

self.addEventListener('activate',e=>{
  e.waitUntil((async()=>{
    const keep=[SHELL,IMGS,DATA];
    const names=await caches.keys();
    await Promise.all(names.map(n=>keep.includes(n)?null:caches.delete(n)));
    await self.clients.claim();
  })());
});

/* Keep a cache from growing without end: oldest entries go first. */
async function trim(name,max){
  const c=await caches.open(name);
  const keys=await c.keys();
  if(keys.length<=max)return;
  for(const k of keys.slice(0,keys.length-max))await c.delete(k);
}

/* One entry per page, whatever query string happened to be on the request.
   Matching while ignoring the query but storing with it kept the canonical
   entry from ever being refreshed: every '?x=1' visit wrote a new key and
   read the stale old one. So the key is always the bare path.         */
function shellKey(req){
  const u=new URL(req.url);
  u.search='';u.hash='';
  return new Request(u.toString(),{credentials:'same-origin'});
}
async function shell(req){
  const c=await caches.open(SHELL);
  const key=shellKey(req);
  const hit=await c.match(key);
  const fresh=fetch(req).then(r=>{
    if(r&&r.ok)c.put(key,r.clone());
    return r;
  }).catch(()=>null);
  /* cached first, so the page paints without waiting on the network */
  return hit || (await fresh) || new Response(
    '<h1>Offline</h1><p>The binder has not been saved to this device yet. '+
    'Open it once with a connection and it will work without one after that.</p>',
    {headers:{'Content-Type':'text/html; charset=utf-8'},status:503});
}

async function image(req){
  const c=await caches.open(IMGS);
  const hit=await c.match(req);
  if(hit)return hit;
  try{
    const r=await fetch(req);
    if(r&&(r.ok||r.type==='opaque')){ await c.put(req,r.clone()); trim(IMGS,IMG_CAP); }
    return r;
  }catch(e){ return hit || Response.error(); }
}

/* The card pool and the exchange rate: newest wins, but a stale copy beats
   nothing, which is what lets the app start up with no signal.          */
async function data(req){
  const c=await caches.open(DATA);
  try{
    const r=await fetch(req);
    if(r&&r.ok)c.put(req,r.clone());
    return r;
  }catch(e){
    const hit=await c.match(req);
    if(hit)return hit;
    throw e;
  }
}

self.addEventListener('fetch',e=>{
  const req=e.request;
  if(req.method!=='GET')return;
  const url=new URL(req.url);

  /* the page itself, however it was asked for */
  if(req.mode==='navigate'||(url.origin===location.origin&&/\.html?$/.test(url.pathname))){
    e.respondWith(shell(req));return;
  }
  if(url.origin===location.origin){
    if(/\.(webmanifest|svg|png|ico|css|js)$/.test(url.pathname)){e.respondWith(shell(req));return;}
    return;
  }
  if(/images\.ygoprodeck\.com|card\.yuyu-tei\.jp/.test(url.hostname)){e.respondWith(image(req));return;}
  if(/db\.ygoprodeck\.com|open\.er-api\.com/.test(url.hostname)){e.respondWith(data(req));return;}
});
