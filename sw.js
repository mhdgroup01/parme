// Paruay service worker — Web Push for POS orders (v1, 2026-06-16)
// NOTE: a service worker MUST be its own file (browser requirement) — it cannot
// live inside the single-file index.html. This SW only does push; no offline cache.

self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (e) { e.waitUntil(self.clients.claim()); });

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
