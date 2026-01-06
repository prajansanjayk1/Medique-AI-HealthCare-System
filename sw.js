importScripts('https://storage.googleapis.com/workbox-cdn/releases/6.4.1/workbox-sw.js');

if (workbox) {
    console.log(`Workbox is loaded`);

    // Force updates to the waiting service worker
    self.workbox.core.skipWaiting();
    self.workbox.core.clientsClaim();

    // Cache Names
    const CACHE_NAME = 'medique-v4-workbox';

    // Precache crucial files - Manual precaching using Workbox routing
    // Note: In a build process, workbox-precaching would be used. 
    // Here we use runtime caching for core files with NetworkFirst to ensure freshness.

    // 1. HTML Pages: Network First (Fresh content is critical, fallback to cache)
    workbox.routing.registerRoute(
        ({request}) => request.destination === 'document',
        new workbox.strategies.NetworkFirst({
            cacheName: 'html-cache',
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
            cacheName: 'assets-cache',
        })
    );

    // 3. Images: Cache First (They rarely change)
    workbox.routing.registerRoute(
        ({request}) => request.destination === 'image',
        new workbox.strategies.CacheFirst({
            cacheName: 'image-cache',
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
            cacheName: 'google-fonts',
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
            cacheName: 'firebase-sdk',
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
