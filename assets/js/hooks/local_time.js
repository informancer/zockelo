// LocalTime hook — replaces element text with a localized datetime string.
// Usage: <time data-timestamp="2024-01-15T14:30:00Z" phx-hook="LocalTime" id="...">...</time>
// The element's text is replaced with the browser's local timezone representation.

const LocalTime = {
  mounted() { this._format() },
  updated() { this._format() },
  _format() {
    const iso = this.el.dataset.timestamp
    if (!iso) return
    const date = new Date(iso)
    if (isNaN(date)) return
    this.el.textContent = new Intl.DateTimeFormat(undefined, {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    }).format(date)
    this.el.setAttribute("title", date.toISOString())
  },
}

export default LocalTime
