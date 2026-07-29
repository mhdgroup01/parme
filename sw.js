// Parme service worker — Web Push + offline app-shell cache (v3, 2026-07-13)
// NOTE: a service worker MUST be its own file (browser requirement) — it cannot
// live inside the single-file index.html.
//
// Cache strategy (ออกแบบให้ "อัปเดตเด้งเอง ไม่ติดเวอร์ชันเก่า"):
//   • cache name ผูกกับเวอร์ชันแอป (ส่งผ่าน ?v= ตอน register) → ทุก deploy = cache ใหม่ + ลบเก่า
//   • HTML (navigation): network-first → ออนไลน์ได้ของใหม่เสมอ, ออฟไลน์ค่อย fallback cache
//   • Supabase JS lib: cache-first → ออฟไลน์ก็โหลด lib ได้
//   • คำขออื่น (Supabase REST/realtime, CDN อื่น): ไม่แตะ — ปล่อยให้แอปจัดการเอง (localStorage)

var VER = (function () { try { return new URL(self.location).searchParams.get('v') || '0'; } catch (e) { return '0'; } })();
var CACHE_PREFIX = 'parme-shell-';
// v3.7.393 — เปลี่ยนชื่อแบรนด์: ต้องกวาด cache ชื่อเดิมทิ้งด้วย ไม่งั้นค้างในเครื่องผู้ใช้ตลอดไป
var OLD_PREFIXES = ['paruay-shell-'];
var CACHE = CACHE_PREFIX + VER;
// v3.7.423 — แคชของรูปที่แยกออกจาก index.html (ยันต์ / GIF สอนติดตั้ง iOS / รูปสินค้าตัวอย่าง)
// ⚠️ **ชื่อคงที่ ห้ามผูกเวอร์ชัน** — ไฟล์พวกนี้เป็นรูปนิ่งที่ไม่เปลี่ยนตามเวอร์ชันแอป
//    ถ้าผูกเวอร์ชัน ทุก deploy จะล้างทิ้งแล้วผู้ใช้ต้องโหลดรูปใหม่ทั้งชุด = ย้อนกลับไปแย่กว่าเดิม
//    (activate ลบเฉพาะคีย์ที่ขึ้นต้นด้วย CACHE_PREFIX/OLD_PREFIXES ⇒ ชื่อนี้รอดโดยตั้งใจ)
var ASSET_CACHE = 'parme-assets';
var SHELL = './';
var SUPA_LIB = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.min.js';
var XLSX_LIB = 'https://cdn.jsdelivr.net/npm/xlsx-js-style@1.2.0/dist/xlsx.bundle.js'; // v3.7.234 — Export Excel (มี style) ออฟไลน์

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
      // CacheStorage เป็นของทั้ง origin (parme.me) ไม่ใช่ของ SW scope นี้ —
      // ลบเฉพาะ cache ของ Parme เอง (prefix ปัจจุบัน + ชื่อเก่า) ไม่งั้นไปกวาด offline shell ของแอปอื่นบน origin เดียวกัน
      var keys = await caches.keys();
      await Promise.all(keys.map(function (k) {
        var mine = k.indexOf(CACHE_PREFIX) === 0;
        var old = OLD_PREFIXES.some(function (p) { return k.indexOf(p) === 0; });
        return ((mine && k !== CACHE) || old) ? caches.delete(k) : null;
      }));
    } catch (_) {}
    try { await self.clients.claim(); } catch (_) {}
  })());
});

// network-first แต่ "มี timeout" (v3.7.246): เน็ตแกว่ง (เชื่อมได้แต่ข้อมูลไม่ไหล เช่นหลังปิด
// airplane mode / สัญญาณอ่อน) → fetch() ค้างได้นานมากโดยไม่ throw → หน้าเว็บไม่ paint → ค้างที่
// OS splash (ต้อง force-quit). กันด้วยการแข่ง fetch กับตัวจับเวลา: ครบเวลายังไม่ได้เน็ต + มี cache
// → คืน cache ให้เข้าแอปก่อน (fetch ที่ค้างยังวิ่งต่อ อัปเดต cache ให้รอบหน้า). ระบบอัปเดตเวอร์ชัน
// ยังทำงาน: SW ใหม่ (bytes เปลี่ยน) install แล้วดึง HTML สดเองใน event 'install'.
var NAV_TIMEOUT = 5000;
async function networkFirst(req) {
  var cache = await caches.open(CACHE);
  var cachedP = cache.match(SHELL);
  try {
    return await new Promise(function (resolve, reject) {
      var done = false;
      fetch(req).then(function (r) {
        if (r && (r.ok || r.type === 'opaqueredirect')) { cache.put(SHELL, r.clone()).catch(function () {}); }
        if (!done) { done = true; resolve(r); }
      }).catch(function (e) {
        if (done) return;
        cachedP.then(function (c) { if (done) return; done = true; c ? resolve(c) : reject(e); });
      });
      setTimeout(function () {
        if (done) return;
        cachedP.then(function (c) { if (c && !done) { done = true; resolve(c); } }); // ไม่มี cache = รอ fetch ต่อ (ไม่มีอะไรดีกว่าแสดง)
      }, NAV_TIMEOUT);
    });
  } catch (err) {
    var cached = await cachedP;
    if (cached) return cached;
    throw err;
  }
}

async function cacheFirstIn(cacheName, req) {
  var cache = await caches.open(cacheName);
  var cached = await cache.match(req);
  if (cached) return cached;
  var res = await fetch(req);
  if (res && res.ok) { try { await cache.put(req, res.clone()); } catch (_) {} }
  return res;
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
  // 1b) v3.7.423 — รูปที่แยกออกจาก index.html → cache-first ในแคชชื่อคงที่
  //     เจตนา: **ไม่โหลดจนกว่าจะใช้จริง** (ผู้ใช้ส่วนใหญ่ไม่เคยเปิดตำราติดตั้ง iOS / ไม่ได้ใช้เมนูตัวอย่าง)
  //     พอใช้ครั้งแรกแล้วอยู่ในเครื่องถาวร ⇒ ออฟไลน์รอบหน้าก็ยังเห็น และ deploy ใหม่ไม่ล้างทิ้ง
  if (url.origin === self.location.origin && url.pathname.indexOf('/assets/') !== -1) {
    e.respondWith(cacheFirstIn(ASSET_CACHE, req)); return;
  }
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
