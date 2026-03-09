// Tooltip hook — adds ESC-to-dismiss keyboard support for accessible tooltips.
// The CSS hover/focus-within rules handle show/hide; this hook adds keyboard dismiss.
const Tooltip = {
  mounted() {
    this.onKeydown = (e) => {
      if (e.key === "Escape") {
        const trigger = this.el.querySelector("[tabindex]")
        if (trigger) trigger.blur()
      }
    }
    this.el.addEventListener("keydown", this.onKeydown)
  },
  destroyed() {
    this.el.removeEventListener("keydown", this.onKeydown)
  }
}

export default Tooltip
