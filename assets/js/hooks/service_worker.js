// Registers the service worker and shows a reload banner when a new version is available.
// Attach to a container element (e.g. the body or a top-level div) with phx-hook="ServiceWorker".

const ServiceWorker = {
  mounted() {
    if (!("serviceWorker" in navigator)) return

    navigator.serviceWorker
      .register("/sw.js")
      .then((registration) => {
        registration.addEventListener("updatefound", () => {
          const worker = registration.installing
          if (!worker) return
          worker.addEventListener("statechange", () => {
            if (worker.state === "installed" && navigator.serviceWorker.controller) {
              this._showReloadBanner()
            }
          })
        })
      })
      .catch((err) => console.warn("SW registration failed:", err))

    // If we just activated a new SW, reload for a clean state.
    let refreshing = false
    navigator.serviceWorker.addEventListener("controllerchange", () => {
      if (!refreshing) {
        refreshing = true
        window.location.reload()
      }
    })
  },

  _showReloadBanner() {
    const banner = document.createElement("div")
    banner.id = "sw-update-banner"
    banner.className =
      "fixed bottom-4 left-1/2 -translate-x-1/2 z-50 alert alert-info shadow-lg w-auto max-w-sm"
    banner.innerHTML = `
      <span>A new version is available.</span>
      <button class="btn btn-sm btn-primary" id="sw-reload-btn">Reload</button>
    `
    document.body.appendChild(banner)
    document.getElementById("sw-reload-btn").addEventListener("click", () => {
      navigator.serviceWorker.controller?.postMessage("skipWaiting")
    })
  },
}

export default ServiceWorker
