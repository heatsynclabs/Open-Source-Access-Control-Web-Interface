import { Controller } from "@hotwired/stimulus"

// Shows only the note that goes with the option chosen in a select (the
// pays-by choice and its instructions). Without JavaScript every note shows.
export default class extends Controller {
  static targets = ["select", "note"]

  connect() {
    this.show()
  }

  show() {
    const value = this.selectTarget.value
    this.noteTargets.forEach((note) => { note.hidden = note.dataset.value !== value })
  }
}
