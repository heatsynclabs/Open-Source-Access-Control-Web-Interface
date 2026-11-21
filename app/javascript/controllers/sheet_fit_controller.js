import { Controller } from "@hotwired/stimulus"

// Zooms the 11 inch wide cheat sheet (1056 CSS pixels) to fit its frame on
// screen. Printing sets its own zoom (laser_sheet_page_style).
export default class extends Controller {
  static targets = ["sheet"]

  connect() {
    this.fit = this.fit.bind(this)
    this.observer = new ResizeObserver(this.fit)
    this.observer.observe(this.element)
    this.fit()
  }

  disconnect() {
    this.observer.disconnect()
  }

  fit() {
    const width = this.element.clientWidth
    if (width) this.sheetTarget.style.setProperty("--z", (width / 1056).toFixed(4))
  }
}
