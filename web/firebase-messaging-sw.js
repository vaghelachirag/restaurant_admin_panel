// firebase-messaging-sw.js — web/firebase-messaging-sw.js

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

self.addEventListener('install', () => {
  console.log('[SW] install — skipWaiting');
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  console.log('[SW] activate — claiming clients');
  event.waitUntil(clients.claim());
});

firebase.initializeApp({
  apiKey:            "AIzaSyDaLMBg9Q0nCMgo_jvGWKDeXPIS_cgHvxk",           // from firebase_options.dart web section
  authDomain:        "restaurant-menu-system-fc074.firebaseapp.com",
  projectId:         "restaurant-menu-system-fc074",
  storageBucket:     "restaurant-menu-system-fc074.appspot.com",
  messagingSenderId: "1561871725",
  appId:             "1:1561871725:web:dff9453c56f11b81a8c664",  // ← WEB appId from firebase_options.dart
});

const messaging = firebase.messaging();

// ─────────────────────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────────────────────
function buildTag(orderId, status) {
  if (orderId && status) return 'order-' + orderId + '-' + status;
  if (orderId)           return 'order-' + orderId;
  return 'order-' + Date.now();
}

function showNotification(title, body, orderId, restaurantId, status) {
  const tag = buildTag(orderId, status);
  console.log('[SW] showNotification — title:', title, '| tag:', tag);
  return self.registration.showNotification(title, {
    body,
    icon:     '/icons/Icon-maskable-192.png', // ← maskable icon has solid background
    badge:    '/icons/Icon-maskable-192.png', // ← shows in status bar on Android
    vibrate:  [200, 100, 200],
    tag,
    renotify: false,
    data: {
      orderId,
      restaurantId,
      status,
      url: self.location.origin + '/#/order/' + restaurantId + '/' + orderId,
    },
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  BACKGROUND MESSAGE
//  Check if any tab is open — if yes Flutter handles it, SW skips.
//  If no tab open — SW shows the notification.
// ─────────────────────────────────────────────────────────────────────────────
messaging.onBackgroundMessage((payload) => {
  const title   = payload.notification?.title || 'Order Update';
  const body    = payload.notification?.body  || '';
  const orderId = payload.data?.orderId        || '';
  const restId  = payload.data?.restaurantId   || '';
  const status  = payload.data?.status         || '';

  console.log('[SW] onBackgroundMessage received:', title);

  return clients.matchAll({
    type:                'window',
    includeUncontrolled: true,
  }).then((clientList) => {
    const ourClients = clientList.filter(
      (c) => c.url.startsWith(self.location.origin)
    );

    console.log('[SW] Open clients count:', ourClients.length);

    if (ourClients.length > 0) {
      console.log('[SW] Tab open — Flutter handles it — skipping');
      return;
    }

    console.log('[SW] No tab open — showing notification');
    return showNotification(title, body, orderId, restId, status);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
//  FOREGROUND MESSAGE from Flutter (JSON string via postMessage)
// ─────────────────────────────────────────────────────────────────────────────
self.addEventListener('message', (event) => {
  let data = event.data;

  if (typeof data === 'string') {
    try { data = JSON.parse(data); }
    catch (e) { console.warn('[SW] JSON parse failed:', e); return; }
  }

  if (!data) return;

  if (data.type === 'SHOW_NOTIFICATION') {
    console.log('[SW] SHOW_NOTIFICATION from Flutter:', data.title);
    showNotification(
      data.title        || 'Order Update',
      data.body         || '',
      data.orderId      || '',
      data.restaurantId || '',
      data.status       || '',
    );
    return;
  }

  console.log('[SW] ignoring message type:', data?.type);
});

// ─────────────────────────────────────────────────────────────────────────────
//  NOTIFICATION CLICK
// ─────────────────────────────────────────────────────────────────────────────
self.addEventListener('notificationclick', (event) => {
  console.log('[SW] notificationclick');
  event.notification.close();

  const notifData    = event.notification.data || {};
  const orderId      = notifData.orderId        || '';
  const restaurantId = notifData.restaurantId   || '';
  const targetUrl    = orderId && restaurantId
    ? self.location.origin + '/#/order/' + restaurantId + '/' + orderId
    : self.location.origin + '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const client of list) {
        if (client.url.startsWith(self.location.origin)) {
          return client.focus().then(() => {
            client.postMessage(JSON.stringify({
              type: 'NAVIGATE_TO_ORDER', orderId, restaurantId,
            }));
          });
        }
      }
      if (clients.openWindow) return clients.openWindow(targetUrl);
    })
  );
});