import { Controller } from "@hotwired/stimulus"

// Keeps the remote door page's door state current, every minute, from the
// same public JSON the page always used (space_api/simple.json).
export default class extends Controller {
  static targets = ["door"]

  connect() {
    this.refresh()
    this.timer = setInterval(() => this.refresh(), 60000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async refresh() {
    try {
      const status = await (await fetch("/space_api/simple.json")).json()
      this.doorTargets.forEach((door) => this.showDoor(door, status[door.dataset.key]))
    } catch (error) {
      // Offline or the site is restarting; the next minute tries again.
    }
  }

  showDoor(door, locked) {
    const state = locked == null ? "unknown" : locked ? "locked" : "unlocked"
    door.classList.remove("locked", "unlocked", "unknown")
    door.classList.add(state)
    door.querySelector(".state").textContent = state === "unknown" ? "Unknown" : state[0].toUpperCase() + state.slice(1)
  }
}
