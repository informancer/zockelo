// ThemeToggle hook — toggles between light and dark themes.
// Reads current theme from localStorage ("phx:theme") and cycles light ↔ dark.
// Dispatches "phx:set-theme" which is handled by the inline script in root.html.heex.

const ThemeToggle = {
  mounted() {
    this._sync()
    this.el.addEventListener("click", () => {
      const current = localStorage.getItem("phx:theme") ||
        (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
      const next = current === "dark" ? "light" : "dark"
      this.el.dataset.phxTheme = next
      this.el.dispatchEvent(new Event("phx:set-theme", {bubbles: true}))
      this._sync()
    })
  },
  updated() { this._sync() },
  _sync() {
    const theme = localStorage.getItem("phx:theme") ||
      (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
    const isDark = theme === "dark"
    this.el.setAttribute("aria-label", isDark ? "Switch to light mode" : "Switch to dark mode")
    this.el.setAttribute("data-current-theme", theme)
  },
}

export default ThemeToggle
