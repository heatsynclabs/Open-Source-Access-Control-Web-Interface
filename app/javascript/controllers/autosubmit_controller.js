import { Controller } from "@hotwired/stimulus"

// Submits the form as soon as a filter changes, so a select acts at once
// (as the door log's type filter always has). The submit button stays for
// keyboards and for the date fields.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
