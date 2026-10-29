import { Controller } from "@hotwired/stimulus"

// The Manage row is a <details> that starts open. On narrow screens it folds
// away behind its "Manage" summary so the header stays short.
export default class extends Controller {
  connect() {
    if (window.matchMedia("(max-width: 799px)").matches) this.element.open = false
  }
}
