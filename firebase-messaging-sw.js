importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAlLK95wyvpQ-AM4ybrzldy0GIjljL79Kw",
  authDomain: "aishwaryam-acu.firebaseapp.com",
  projectId: "aishwaryam-acu",
  storageBucket: "aishwaryam-acu.firebasestorage.app",
  messagingSenderId: "465782673272",
  appId: "1:465782673272:web:d8daadbe2f6b7308bec28d",
  measurementId: "G-00XFE2VC97"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  // Customize notification here
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icon-192x192.png', // Ensure this icon exists
    badge: '/icon-192x192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
