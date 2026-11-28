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
  const data = message.data || {};
  event.waitUntil(
    self.registration.showNotification(title, {
      body: message.body || '',
      icon: base + 'icons/Icon-192.png',
      badge: base + 'icons/Icon-192.png',
      // url: where a tap lands (the weekly recap sends "/?shortcut=insights").
      // Only addresses on the app's own site; anything else opens the app.
      data: { ...data, url: sameSite(data.url, base), home: base },
    })
  );
});

function sameSite(url, base) {
  try {
    const full = new URL(url || base, base);
    return full.origin === new URL(base).origin ? full.href : base;
  } catch (e) {
    return base;
  }
}

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const home = data.home || new URL('../', self.registration.scope).href;
  const target = sameSite(data.url, home);
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      // The app already open in a tab: bring it forward as it is (it is not
      // reloaded, so nothing typed there is lost). Otherwise open it at the
      // notification's address, e.g. on Insights.
      for (const client of windows) {
        if (client.url.startsWith(home) && 'focus' in client) return client.focus();
      }
      return self.clients.openWindow(target);
    })
  );
});
