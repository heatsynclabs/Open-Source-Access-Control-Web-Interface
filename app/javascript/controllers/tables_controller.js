import { Controller } from "@hotwired/stimulus"

// Gets data tables ready to stack into cards on phones (see tables.scss):
// each cell learns its column name from the header row. Tables with fewer
// than three columns, or marked .no-stack, stay as they are.
export default class extends Controller {
  connect() {
    this.element.querySelectorAll("table:not(.no-stack)").forEach((table) => {
      const headers = [...table.querySelectorAll("thead th")].map((th) => th.textContent.trim())
      if (headers.length < 3) return
      table.classList.add("stack")
      table.querySelectorAll("tbody tr").forEach((row) => {
        ;[...row.children].forEach((cell, index) => { cell.dataset.label = headers[index] || "" })
      })
    })
  }
}
