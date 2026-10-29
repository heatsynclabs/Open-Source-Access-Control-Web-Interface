import { Controller } from "@hotwired/stimulus"

// Narrows a list or table as you type. Each item carries the text to search
// in data-filter-text; toggles and selects narrow further by matching an
// item's data attributes:
//
//   <button data-filter-target="toggle" data-key="cards" aria-pressed="false">
//     shows only items with data-cards="true" while pressed
//   <select data-filter-target="select" data-key="certs">
//     shows only items whose data-certs (a | separated list) holds the value
export default class extends Controller {
  static targets = ["query", "item", "toggle", "select", "count", "none"]
  static values = { noun: { type: String, default: "items" } }

  connect() {
    this.apply()
  }

  flip(event) {
    const button = event.currentTarget
    button.setAttribute("aria-pressed", button.getAttribute("aria-pressed") === "true" ? "false" : "true")
    this.apply()
  }

  apply() {
    const words = this.hasQueryTarget ? this.queryTarget.value.trim().toLowerCase().split(/\s+/).filter(Boolean) : []
    let shown = 0

    this.itemTargets.forEach((item) => {
      const visible = this.matchesWords(item, words) && this.matchesToggles(item) && this.matchesSelects(item)
      item.hidden = !visible
      if (visible) shown++
    })

    this.report(shown)
  }

  matchesWords(item, words) {
    const text = (item.dataset.filterText || item.textContent).toLowerCase()
    return words.every((word) => text.includes(word))
  }

  matchesToggles(item) {
    return this.toggleTargets.every((toggle) =>
      toggle.getAttribute("aria-pressed") !== "true" || item.dataset[toggle.dataset.key] === "true")
  }

  matchesSelects(item) {
    return this.selectTargets.every((select) =>
      !select.value || (item.dataset[select.dataset.key] || "").split("|").includes(select.value))
  }

  report(shown) {
    const total = this.itemTargets.length
    if (this.hasCountTarget) {
      this.countTarget.textContent = shown === total ? `${total} ${this.nounValue}` : `${shown} of ${total} ${this.nounValue}`
    }
    if (this.hasNoneTarget) this.noneTarget.hidden = shown !== 0
  }
}
