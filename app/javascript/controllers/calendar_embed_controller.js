import { Controller } from "@hotwired/stimulus"

// Sizes the embedded calendar iframe to the height of its content, so the
// calendar flows in the page and the whole page scrolls as one. Without this
// the iframe is a fixed box and the tall calendar scrolls inside it, which
// traps touch scrolling on phones.
//
// The embedded page (heatsynclabs.org/calendar/embed) posts its height with
// window.postMessage. We only trust messages from that iframe's own origin.
export default class extends Controller {
  static targets = ["frame"]

  connect() {
    this.origin = new URL(this.frameTarget.src, window.location.href).origin
    this.onMessage = this.onMessage.bind(this)
    window.addEventListener("message", this.onMessage)
  }

  disconnect() {
    window.removeEventListener("message", this.onMessage)
  }

  onMessage(event) {
    if (event.origin !== this.origin) return
    const data = event.data
    if (!data || data.type !== "hsl-calendar-height") return

    // Guard against a bad or runaway value; fall back to the CSS height if so.
    const height = Number(data.height)
    if (Number.isFinite(height) && height > 200 && height < 20000) {
      this.frameTarget.style.height = `${Math.ceil(height)}px`
    }
  }
}
