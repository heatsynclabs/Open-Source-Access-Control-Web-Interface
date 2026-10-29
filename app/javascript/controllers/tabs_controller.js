import { Controller } from "@hotwired/stimulus"

// Tabs over panels on one page. The open tab is kept in the URL hash so a
// link or a reload lands on the same tab; without one, the tab named by
// data-tabs-default-value (or the first) opens.
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { default: String }

  connect() {
    const named = (name) => this.tabTargets.find((tab) => tab.dataset.name === name)
    this.show(named(window.location.hash.slice(1)) || named(this.defaultValue) || this.tabTargets[0])
  }

  select(event) {
    this.show(event.currentTarget)
    history.replaceState(null, "", `#${event.currentTarget.dataset.name}`)
  }

  show(activeTab) {
    if (!activeTab) return
    this.tabTargets.forEach((tab) => tab.setAttribute("aria-selected", tab === activeTab ? "true" : "false"))
    this.panelTargets.forEach((panel) => { panel.hidden = panel.dataset.name !== activeTab.dataset.name })
  }
}
