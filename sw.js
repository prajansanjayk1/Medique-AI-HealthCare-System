importScripts('https://storage.googleapis.com/workbox-cdn/releases/6.4.1/workbox-sw.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

if (workbox) {
    console.log(`Workbox is loaded`);

    // Force updates to the waiting service worker
    self.workbox.core.skipWaiting();
    self.workbox.core.clientsClaim();

    // Cache Names
    const CACHE_NAME = 'medique-v6-workbox';
    const ACTIVE_CACHES = new Set([
        'html-cache-v2',
        'assets-cache-v2',
        'image-cache-v2',
        'google-fonts-v2',
        'firebase-sdk-v2',
    ]);

    self.addEventListener('activate', (event) => {
        event.waitUntil(
            caches.keys().then((keys) =>
                Promise.all(
                    keys.map((key) => {
                        if (!ACTIVE_CACHES.has(key)) {
                            return caches.delete(key);
                        }
                        return Promise.resolve();
                    })
                )
            )
        );
    });

    // Precache crucial files - Manual precaching using Workbox routing
    // Note: In a build process, workbox-precaching would be used. 
    // Here we use runtime caching for core files with NetworkFirst to ensure freshness.

    // 1. HTML Pages: Network First (Fresh content is critical, fallback to cache)
    workbox.routing.registerRoute(
        ({request}) => request.destination === 'document',
        new workbox.strategies.NetworkFirst({
            cacheName: 'html-cache-v2',
            plugins: [
                new workbox.expiration.ExpirationPlugin({
                    maxEntries: 10,
                }),
            ],
        })
    );

    // 2. CSS/JS/Manifest: Stale While Revalidate (Fast load, update in background)
    workbox.routing.registerRoute(
        ({request}) => request.destination === 'script' || 
                       request.destination === 'style' || 
                       request.destination === 'manifest',
        new workbox.strategies.StaleWhileRevalidate({
            cacheName: 'assets-cache-v2',
        })
    );

    // 3. Images: Cache First (They rarely change)
    workbox.routing.registerRoute(
        ({request}) => request.destination === 'image',
        new workbox.strategies.CacheFirst({
            cacheName: 'image-cache-v2',
            plugins: [
                new workbox.expiration.ExpirationPlugin({
                    maxEntries: 50,
                    maxAgeSeconds: 30 * 24 * 60 * 60, // 30 Days
                }),
            ],
        })
    );

    // 4. Google Fonts: Cache First
    workbox.routing.registerRoute(
        ({url}) => url.origin === 'https://fonts.googleapis.com' || 
                   url.origin === 'https://fonts.gstatic.com',
        new workbox.strategies.CacheFirst({
            cacheName: 'google-fonts-v2',
            plugins: [
                new workbox.expiration.ExpirationPlugin({
                    maxEntries: 20,
                    maxAgeSeconds: 365 * 24 * 60 * 60, // 1 Year
                }),
            ],
        })
    );

    // 5. Firebase Scripts: Stale While Revalidate
    workbox.routing.registerRoute(
        ({url}) => url.origin === 'https://www.gstatic.com',
        new workbox.strategies.StaleWhileRevalidate({
            cacheName: 'firebase-sdk-v2',
        })
    );
    
     // Offline fallback
    const offlineFallbackPage = 'offline.html';
    // self.addEventListener('install', async (event) => {
    //     event.waitUntil(
    //         caches.open('offline-cache').then((cache) => cache.add(offlineFallbackPage))
    //     );
    // });

} else {
    console.log(`Workbox didn't load`);
}

// Firebase Cloud Messaging background notifications (app closed/minimized)
try {
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
        const title = payload?.notification?.title || "MediQue";
        const body = payload?.notification?.body || "Queue update available.";
        const clickAction = payload?.data?.click_action || payload?.fcmOptions?.link || "/patient.html";

        self.registration.showNotification(title, {
            body,
            icon: "/icon-192x192.png",
            badge: "/icon-192x192.png",
            tag: "medique-queue-alert",
            renotify: true,
            requireInteraction: true,
            vibrate: [300, 150, 300, 150, 500],
            data: { click_action: clickAction }
        });
    });

    self.addEventListener("notificationclick", (event) => {
        event.notification.close();
        const targetUrl = event.notification?.data?.click_action || "/patient.html";
        event.waitUntil(
            clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
                for (const client of clientList) {
                    if (client.url.includes("/patient.html")) {
                        return client.focus();
                    }
                }
                return clients.openWindow(targetUrl);
            })
        );
    });
} catch (err) {
    console.warn("FCM service worker init failed:", err);
}
