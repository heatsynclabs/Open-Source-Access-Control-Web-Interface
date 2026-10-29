import { Controller } from "@hotwired/stimulus"

// Opens the <dialog> named by a trigger's data-dialog-id, and closes it on
// its close button or a click on the backdrop.
export default class extends Controller {
  open(event) {
    const dialog = document.getElementById(event.currentTarget.dataset.dialogId)
    if (!dialog) return
    event.preventDefault()
    dialog.showModal()
  }

  close(event) {
    event.target.closest("dialog")?.close()
  }

  backdrop(event) {
    if (event.target.tagName === "DIALOG") event.target.close()
  }
}
