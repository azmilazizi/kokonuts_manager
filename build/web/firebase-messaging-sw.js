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

function fmtCurrency(value) {
  const n = parseFloat(value);
  if (isNaN(n)) return value;
  return 'RM ' + n.toLocaleString('en-MY', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function fmtTimestamp(isoString) {
  try {
    return new Date(isoString).toLocaleString('en-MY', {
      day: 'numeric', month: 'short', year: 'numeric',
      hour: 'numeric', minute: '2-digit', hour12: true,
    });
  } catch (_) {
    return isoString;
  }
}

messaging.onBackgroundMessage((payload) => {
  const data = payload.data ?? {};
  const type = data.type ?? '';

  let title, body;

  if (type === 'shift_opened') {
    const warehouse = data.warehouse_name ? ` — ${data.warehouse_name}` : '';
    title = `Shift Opened${warehouse}`;
    const parts = [];
    if (data.opened_at) parts.push(fmtTimestamp(data.opened_at));
    if (data.opening_cash != null) parts.push(`Opening: ${fmtCurrency(data.opening_cash)}`);
    body = parts.join('\n') || payload.notification?.body || '';
  } else if (type === 'shift_closed') {
    const warehouse = data.warehouse_name ? ` — ${data.warehouse_name}` : '';
    title = `Shift Closed${warehouse}`;
    const parts = [];
    if (data.closing_cash != null) parts.push(`Closing: ${fmtCurrency(data.closing_cash)}`);
    if (data.cash_difference != null) {
      const diff = parseFloat(data.cash_difference);
      const sign = diff >= 0 ? '+' : '';
      parts.push(`Difference: ${sign}${fmtCurrency(data.cash_difference)}`);
    }
    body = parts.join('\n') || payload.notification?.body || '';
  } else {
    title = payload.notification?.title ?? 'Kokonuts';
    body = payload.notification?.body ?? '';
  }

  return self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: type || 'kokonuts',
    requireInteraction: true,
    data: data,
  });
});
