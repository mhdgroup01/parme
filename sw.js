// Paruay service worker — Web Push + offline app-shell cache (v2, 2026-06-29)
// NOTE: a service worker MUST be its own file (browser requirement) — it cannot
// live inside the single-file index.html.
//
// Cache strategy (ออกแบบให้ "อัปเดตเด้งเอง ไม่ติดเวอร์ชันเก่า"):
//   • cache name ผูกกับเวอร์ชันแอป (ส่งผ่าน ?v= ตอน register) → ทุก deploy = cache ใหม่ + ลบเก่า
//   • HTML (navigation): network-first → ออนไลน์ได้ของใหม่เสมอ, ออฟไลน์ค่อย fallback cache
//   • Supabase JS lib: cache-first → ออฟไลน์ก็โหลด lib ได้
//   • คำขออื่น (Supabase REST/realtime, CDN อื่น): ไม่แตะ — ปล่อยให้แอปจัดการเอง (localStorage)

var VER = (function () { try { return new URL(self.location).searchParams.get('v') || '0'; } catch (e) { return '0'; } })();
var CACHE = 'paruay-shell-' + VER;
var SHELL = './';
var SUPA_LIB = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.min.js';
var XLSX_LIB = 'https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js'; // v3.7.233 — Export Excel ออฟไลน์

self.addEventListener('install', function (e) {
  self.skipWaiting();
  e.waitUntil((async function () {
    try {
      var cache = await caches.open(CACHE);
      try { await cache.add(SHELL); } catch (_) {}
      try { await cache.add(SUPA_LIB); } catch (_) {}
      try { await cache.add(XLSX_LIB); } catch (_) {}
    } catch (_) {}
  })());
});

self.addEventListener('activate', function (e) {
  e.waitUntil((async function () {
    try {
      var keys = await caches.keys();
      await Promise.all(keys.map(function (k) { return k !== CACHE ? caches.delete(k) : null; }));
    } catch (_) {}
    try { await self.clients.claim(); } catch (_) {}
  })());
});

async function networkFirst(req) {
  var cache = await caches.open(CACHE);
  try {
    var res = await fetch(req);
    if (res && (res.ok || res.type === 'opaqueredirect')) { try { await cache.put(SHELL, res.clone()); } catch (_) {} }
    return res;
  } catch (err) {
    var cached = await cache.match(SHELL);
    if (cached) return cached;
    throw err;
  }
}

async function cacheFirst(req) {
  var cache = await caches.open(CACHE);
  var cached = await cache.match(req);
  if (cached) return cached;
  var res = await fetch(req);
  if (res && res.ok) { try { await cache.put(req, res.clone()); } catch (_) {} }
  return res;
}

self.addEventListener('fetch', function (e) {
  var req = e.request;
  if (req.method !== 'GET') return;
  var url;
  try { url = new URL(req.url); } catch (_) { return; }
  // 1) HTML document (โหลดแอป) → network-first, fallback cache
  if (req.mode === 'navigate') { e.respondWith(networkFirst(req)); return; }
  // 2) Supabase JS lib → cache-first (ออฟไลน์ก็มี)
  if (url.href.indexOf('supabase') !== -1 && url.href.indexOf('.js') !== -1 && url.origin !== self.location.origin) {
    e.respondWith(cacheFirst(req)); return;
  }
  // 2b) SheetJS (Export Excel) → cache-first (ออฟไลน์ export ได้หลังโหลดครั้งแรก)
  if (url.href.indexOf('xlsx') !== -1 && url.href.indexOf('.js') !== -1 && url.origin !== self.location.origin) {
    e.respondWith(cacheFirst(req)); return;
  }
  // อื่น ๆ: ไม่แตะ (Supabase REST/realtime ต้องวิ่งเน็ตตามปกติ, ออฟไลน์แอปใช้ localStorage)
});

self.addEventListener('push', function (e) {
  var d = {};
  try { d = e.data ? e.data.json() : {}; } catch (_) { try { d = { body: e.data.text() }; } catch (e2) {} }
  var title = d.title || 'ออเดอร์ใหม่';
  var opts = {
    body: d.body || 'มีออเดอร์ใหม่จากลูกค้า',
    tag: d.tag || 'pos-order',
    renotify: true,
    requireInteraction: true,
    vibrate: [200, 100, 200, 100, 200],
    data: { url: d.url || '.' }
  };
  e.waitUntil(self.registration.showNotification(title, opts));
});

self.addEventListener('notificationclick', function (e) {
  e.notification.close();
  var url = (e.notification.data && e.notification.data.url) || '.';
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (cs) {
    for (var i = 0; i < cs.length; i++) { if ('focus' in cs[i]) { return cs[i].focus(); } }
    if (self.clients.openWindow) { return self.clients.openWindow(url); }
  }));
});
