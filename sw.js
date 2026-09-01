const CACHE="audiobook-reviewer-v1";
const ASSETS=["./","./index.html","./manifest.webmanifest"];
self.addEventListener("install",e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(ASSETS))));
self.addEventListener("fetch",e=>{
  e.respondWith(caches.match(e.request).then(r=>r||fetch(e.request).then(resp=>{
    if(e.request.method==="GET"){
      const clone=resp.clone();caches.open(CACHE).then(c=>c.put(e.request,clone)).catch(()=>{});
    }
    return resp;
  })));
});