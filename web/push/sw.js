// Shows push notifications from the NuStreak server. It lives in /push/ so its
// scope never overlaps Flutter's own service worker. It does no caching.

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let message = {};
  try {
    message = event.data ? event.data.json() : {};
  } catch (e) {
    message = { title: 'NuStreak', body: event.data ? event.data.text() : '' };
  }
  const base = new URL('../', self.registration.scope).href;
  const title = message.title || 'NuStreak';
  event.waitUntil(
    self.registration.showNotification(title, {
      body: message.body || '',
      icon: base + 'icons/Icon-192.png',
      badge: base + 'icons/Icon-192.png',
      data: { url: base, ...(message.data || {}) },
    })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = (event.notification.data && event.notification.data.url) || new URL('../', self.registration.scope).href;
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      for (const client of windows) {
        if (client.url.startsWith(target) && 'focus' in client) return client.focus();
      }
      return self.clients.openWindow(target);
    })
  );
});
