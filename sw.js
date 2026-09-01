const CACHE="audiobook-reviewer-v3";
const ASSETS=["./","./index.html","./manifest.webmanifest"];
self.addEventListener("install",e=>{self.skipWaiting();e.waitUntil(caches.open(CACHE).then(c=>c.addAll(ASSETS))) });
self.addEventListener("activate",e=>{e.waitUntil((async()=>{for(const k of await caches.keys()){if(k!==CACHE)await caches.delete(k)}await self.clients.claim()})())});
self.addEventListener("fetch",e=>{
  if(e.request.method!=="GET") return;
  if(e.request.mode==="navigate"){
    e.respondWith(fetch(e.request).then(r=>{const c=r.clone();caches.open(CACHE).then(x=>x.put(e.request,c));return r}).catch(()=>caches.match("./index.html")));
    return;
  }
  e.respondWith(caches.match(e.request).then(r=>r||fetch(e.request).then(resp=>{const c=resp.clone();caches.open(CACHE).then(x=>x.put(e.request,c));return resp})));
});