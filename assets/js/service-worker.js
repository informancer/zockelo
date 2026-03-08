// Service worker for Zockelo PWA.
// Versioned by BUILD_HASH (replaced at build time) — triggers update cycle on deploy.
// Strategy: network-first for navigation; cache-first for static assets.

const CACHE_VERSION = "__BUILD_HASH__"
const STATIC_CACHE = `zockelo-static-${CACHE_VERSION}`
const STATIC_ASSETS = ["/assets/css/app.css", "/assets/js/app.js"]

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => cache.addAll(STATIC_ASSETS))
  )
  // Activate immediately without waiting for old clients to unload.
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((k) => k.startsWith("zockelo-") && k !== STATIC_CACHE)
          .map((k) => caches.delete(k))
      )
    )
  )
  self.clients.claim()
})

self.addEventListener("fetch", (event) => {
  const { request } = event
  const url = new URL(request.url)

  // Only handle same-origin requests.
  if (url.origin !== location.origin) return

  // Navigation: network-first, fall back to cache.
  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request).catch(() =>
        caches.match(request).then((r) => r || fetch(request))
      )
    )
    return
  }

  // Static assets: cache-first.
  if (url.pathname.startsWith("/assets/") || url.pathname.startsWith("/fonts/")) {
    event.respondWith(
      caches.match(request).then((cached) => {
        if (cached) return cached
        return fetch(request).then((response) => {
          if (response.ok) {
            const clone = response.clone()
            caches.open(STATIC_CACHE).then((cache) => cache.put(request, clone))
          }
          return response
        })
      })
    )
  }
})

// Notify clients when a new version is waiting to activate.
self.addEventListener("message", (event) => {
  if (event.data === "skipWaiting") self.skipWaiting()
})
