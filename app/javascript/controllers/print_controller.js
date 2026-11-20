import { Controller } from "@hotwired/stimulus"

// A button that opens the browser's print dialog.
export default class extends Controller {
  print() {
    window.print()
  }
}
