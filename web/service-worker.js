// Replaced at build time with a content hash and the exact public asset list.
const version = __APP_VERSION__;
const paths = __APP_ASSETS__;
const root = new URL('./', self.location.href);
const cachePrefix = `liftosaur-app:${root.pathname}:`;
const cacheName = cachePrefix + version;
const assets = paths.map(path => new URL(path, root).href);

self.addEventListener('install', event => {
  event.waitUntil(caches.open(cacheName).then(cache => cache.addAll(assets)));
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const name of await caches.keys()) {
      if (name.startsWith(cachePrefix) && name !== cacheName) await caches.delete(name);
    }
    await self.clients.claim();
  })());
});

// An update waits until the user chooses to reload, or all old app tabs close.
self.addEventListener('message', event => {
  if (event.data === 'ACTIVATE_UPDATE') self.skipWaiting();
});

self.addEventListener('fetch', event => {
  const request = event.request;
  const url = new URL(request.url);
  // Never intercept account data, API calls, or unrelated sites on this origin.
  if (request.method !== 'GET' || url.origin !== root.origin || request.headers.has('Authorization')) return;
  let target = url.href;
  if (request.mode === 'navigate' && (url.pathname === root.pathname || url.pathname === root.pathname + 'index.html')) {
    target = new URL('index.html', root).href;
  }
  if (!assets.includes(target)) return;
  event.respondWith((async () => {
    const cache = await caches.open(cacheName);
    return await cache.match(target) || fetch(request);
  })());
});
