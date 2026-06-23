// Firebase Cloud Messaging service worker — handles push notifications when the
// app is in the background or closed.
//
// TODO: Replace the firebaseConfig values below to match your firebase_options.dart.

importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBDEXz3a5lwzAKjUTSQHMKDJnLtaPF6NGQ',
  authDomain: 'kokonuts-manager.firebaseapp.com',
  projectId: 'kokonuts-manager',
  storageBucket: 'kokonuts-manager.firebasestorage.app',
  messagingSenderId: '83700561890',
  appId: '1:83700561890:web:e9115663167a0c3240abbb',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title ?? 'Kokonuts';
  const body = payload.notification?.body ?? '';
  const type = payload.data?.type ?? 'shift';

  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: type,
    requireInteraction: true,
    data: payload.data ?? {},
  });
});
