import { Controller } from "@hotwired/stimulus"

// The site header. On wide screens each role menu (Instructor, Treasurer,
// Admin) is a disclosure button that opens its links below it; opening one
// closes the others. On phones the Menu button shows the whole nav as a list.
// Escape or a click elsewhere closes whatever is open.
export default class extends Controller {
  static targets = ["menuButton"]

  toggleMenu() {
    const open = this.menuButtonTarget.getAttribute("aria-expanded") !== "true"
    this.menuButtonTarget.setAttribute("aria-expanded", String(open))
    this.element.classList.toggle("menu-open", open)
  }

  toggleGroup(event) {
    const button = event.currentTarget
    const open = button.getAttribute("aria-expanded") !== "true"
    this.closeGroups()
    button.setAttribute("aria-expanded", String(open))
  }

  closeAll() {
    const openButton = this.element.querySelector(".nav-group-toggle[aria-expanded='true']")
    this.closeGroups()
    if (this.element.classList.contains("menu-open")) {
      this.toggleMenu()
      this.menuButtonTarget.focus()
    } else if (openButton) {
      openButton.focus()
    }
  }

  closeOutside(event) {
    if (!this.element.contains(event.target)) this.closeGroups()
  }

  closeGroups() {
    this.element.querySelectorAll(".nav-group-toggle").forEach((button) => button.setAttribute("aria-expanded", "false"))
  }
}
