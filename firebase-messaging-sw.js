importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyBmhvep0QM24Mf3SesIital2CCETmlsJ-4",
  authDomain: "medique-b29ee.firebaseapp.com",
  projectId: "medique-b29ee",
  storageBucket: "medique-b29ee.firebasestorage.app",
  messagingSenderId: "16979338752",
  appId: "1:16979338752:web:1d4ca34fb54fdad6b55ae5",
  measurementId: "G-PH4EKPV5NL"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload?.notification?.title || payload?.data?.title || "MediQue";
  const clickAction = payload?.data?.target_url || payload?.data?.click_action || "/patient.html";
  const notificationOptions = {
    body: payload?.notification?.body || payload?.data?.body || "Queue update available.",
    icon: '/icon-192x192.png',
    badge: '/icon-192x192.png',
    data: { click_action: clickAction }
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const targetUrl = event.notification?.data?.click_action || "/patient.html";
  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes("/patient.html") || client.url.includes("/doctor.html") || client.url.includes("/admin.html")) {
          return client.focus();
        }
      }
      return clients.openWindow(targetUrl);
    })
  );
});
