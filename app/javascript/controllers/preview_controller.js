import { Controller } from "@hotwired/stimulus"

// Loads an HTML snippet about the chosen record into the panel beside a
// select, e.g. the person summary on the merge page:
//   data-controller="preview" data-preview-url-value="/user_summary/"
export default class extends Controller {
  static targets = ["panel"]
  static values = { url: String }

  async load(event) {
    const id = event.target.value
    if (!id) {
      this.panelTarget.innerHTML = ""
      return
    }
    const response = await fetch(this.urlValue + encodeURIComponent(id), { credentials: "same-origin" })
    this.panelTarget.innerHTML = await response.text()
  }
}
