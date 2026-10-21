// TFTI Firebase Cloud Messaging Service Worker for Web Push
importScripts('https://www.gstatic.com/firebasejs/10.14.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyDZvItN3cMKrWkscHouteMezwGGofxkm60",
  authDomain: "tfti-app.firebaseapp.com",
  projectId: "tfti-app",
  storageBucket: "tfti-app.firebasestorage.app",
  messagingSenderId: "80872957470",
  appId: "1:80872957470:web:99f505d10490e806f0b00f"
});

const messaging = firebase.messaging();

// Handle push notifications when the web app is backgrounded or closed
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message: ', payload);
  const title = payload.notification?.title || payload.data?.title || 'TFTI Alert';
  const body = payload.notification?.body || payload.data?.body || '';
  const notificationOptions = {
    body: body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {}
  };
  return self.registration.showNotification(title, notificationOptions);
});

// Focus or open the TFTI window on notification click
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const eventId = event.notification.data?.eventId;
  const type = event.notification.data?.type;
  let targetPath = '/';
  if (eventId) {
    targetPath = `/?eventId=${encodeURIComponent(eventId)}&type=${encodeURIComponent(type || 'event')}`;
  }

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          if (client.navigate) {
            client.navigate(targetPath);
          }
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetPath);
      }
    })
  );
});
