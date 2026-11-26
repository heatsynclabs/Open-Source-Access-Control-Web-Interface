import { Controller } from "@hotwired/stimulus"

// Reloads the Turbo Frame it sits on every so often, while the tab is in
// view. Used for the window sign's live status.
//
//   <turbo-frame id="x" src="..." data-controller="frame-refresh"
//                data-frame-refresh-every-value="15">
export default class extends Controller {
  static values = { every: { type: Number, default: 15 } }

  connect() {
    this.timer = setInterval(() => this.reload(), Math.max(5, this.everyValue) * 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  reload() {
    if (document.hidden || !this.element.src) return
    // A reload already under way is left to finish.
    if (this.element.hasAttribute("busy")) return
    this.element.reload()
  }
}
