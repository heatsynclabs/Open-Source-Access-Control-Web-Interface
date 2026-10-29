import { Controller } from "@hotwired/stimulus"

// Fills the waiver form from the scan's file name, when the scan is named
//   "first last - 2024-05-01.pdf" or "first last by cosigner name - 2024-05-01.jpg",
// picks the member with that name, and warns when they already have waivers.
export default class extends Controller {
  fill(event) {
    if (event.target.id !== "contract_document") return
    const file = event.target.files && event.target.files[0]
    if (!file) return

    this.field("contract_user_alert")?.remove()
    const parts = file.name.replace(/\.(jpg|pdf)$/i, "").split(" ")

    if (parts.length === 4) {
      this.setNames(parts[0], parts[1])
      this.setDate(parts[3])
    } else if (parts.length === 7 && parts[2] === "by") {
      this.setNames(parts[0], parts[1])
      this.field("contract_cosigner").value = `${capitalized(parts[3])} ${capitalized(parts[4])}`
      this.setDate(parts[6])
    }

    this.selectMember()
  }

  setNames(first, last) {
    this.field("contract_first_name").value = capitalized(first)
    this.field("contract_last_name").value = capitalized(last)
  }

  setDate(text) {
    const signed = new Date(text)
    if (isNaN(signed)) return
    this.field("contract_signed_at_1i").value = signed.getUTCFullYear()
    this.field("contract_signed_at_2i").value = signed.getUTCMonth() + 1
    this.field("contract_signed_at_3i").value = signed.getUTCDate()
  }

  async selectMember() {
    const name = `${this.field("contract_first_name").value} ${this.field("contract_last_name").value}`.trim()
    const select = this.field("contract_user_id")
    const option = [...select.options].find((candidate) => candidate.text === name)
    if (!option) return
    option.selected = true

    const waivers = await (await fetch(`/users/${option.value}/contracts.json`)).json()
    if (waivers.length === 0) return
    const links = waivers.map((waiver) => `<a href="/contracts/${waiver.id}">${waiver.id}</a>`).join(", ")
    this.field("contract_user_notes").innerHTML =
      `<p id="contract_user_alert" class="msg err">This person already has ${waivers.length} waiver(s) on file. Check them so this is not a duplicate: ${links}</p>`
  }

  field(id) {
    return this.element.querySelector(`#${id}`)
  }
}

function capitalized(word) {
  return word ? word[0].toUpperCase() + word.slice(1) : word
}
