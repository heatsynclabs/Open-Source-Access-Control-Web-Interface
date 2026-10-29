import { Controller } from "@hotwired/stimulus"

// Tabs over panels on one page. The open tab is kept in the URL hash so a
// link or a reload lands on the same tab.
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    const fromHash = this.tabTargets.find((tab) => `#${tab.dataset.name}` === window.location.hash)
    this.show(fromHash || this.tabTargets[0])
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
