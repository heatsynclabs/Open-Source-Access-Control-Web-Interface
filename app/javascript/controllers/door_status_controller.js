import { Controller } from "@hotwired/stimulus"

// Keeps the remote door page current: door state and the computers at the
// lab every minute, and a fresh webcam snapshot on request. Reads the same
// public JSON the page always used (space_api/simple.json, macs.json).
export default class extends Controller {
  static targets = ["door", "macs", "camera"]

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
      if (this.hasMacsTarget) {
        const macs = await (await fetch("/macs.json")).json()
        const names = [...new Set(macs.map((mac) => mac.name).filter(Boolean))].sort()
        this.macsTarget.textContent = names.length ? `On the network now: ${names.join(", ")}` : ""
      }
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

  reloadCamera(event) {
    event.preventDefault()
    const url = new URL(this.cameraTarget.src)
    url.searchParams.set("t", Date.now())
    this.cameraTarget.src = url.toString()
  }
}
