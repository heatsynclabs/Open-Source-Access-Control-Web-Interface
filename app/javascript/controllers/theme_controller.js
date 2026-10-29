import { Controller } from "@hotwired/stimulus"

// Light and dark theme switch. The layout's head script applies the saved
// choice before the page paints; this button flips and remembers it.
export default class extends Controller {
  static targets = ["sun", "moon"]

  connect() {
    this.showIcon()
  }

  toggle() {
    const next = this.current === "dark" ? "light" : "dark"
    document.documentElement.dataset.theme = next
    try { localStorage.setItem("gantry-theme", next) } catch (e) { /* private mode */ }
    this.showIcon()
    window.dispatchEvent(new CustomEvent("theme:change", { detail: next }))
  }

  get current() {
    return document.documentElement.dataset.theme
  }

  showIcon() {
    const dark = this.current === "dark"
    this.sunTarget.hidden = !dark
    this.moonTarget.hidden = dark
    this.element.setAttribute("aria-label", dark ? "Switch to the light theme" : "Switch to the dark theme")
  }
}
