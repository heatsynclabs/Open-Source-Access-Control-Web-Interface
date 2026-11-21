import { Controller } from "@hotwired/stimulus"

// The Laser math estimator: from the fitted law (E = k x thickness^b, in J/mm)
// and a chosen power, the speed that leaves the same energy per mm.
// law: { k: { material: k }, b, low, high, thickest: { material: mm }, logged: { material: { mm: jobs } },
//        perPercent: watts per percent of power (0.8 on an 80 W tube) }
export default class extends Controller {
  static targets = ["material", "thickness", "power", "powerLabel", "beam", "output", "note"]
  static values = { law: Object }

  connect() {
    this.update()
  }

  update() {
    const law = this.lawValue
    const material = this.materialTarget.value
    const mm = Math.max(0.5, Number(this.thicknessTarget.value) || 3)
    const power = Number(this.powerTarget.value)
    const energy = law.k[material] * Math.pow(mm, law.b) * Number(this.beamTarget.value)
    const speed = law.perPercent * power / energy
    const fmt = (v) => (v < 10 ? v.toFixed(1) : Math.round(v).toString())
    this.powerLabelTarget.textContent = `${power}%`
    this.outputTarget.replaceChildren(...[[power, "Power %"], [fmt(speed), "Speed mm/s"], [energy.toFixed(1), "J per mm"]].map(([value, label]) => {
      const tile = document.createElement("div")
      tile.className = "tile"
      tile.innerHTML = `<div class="num"></div><div class="label"></div>`
      tile.querySelector(".num").textContent = value
      tile.querySelector(".label").textContent = label
      return tile
    }))
    const logged = (law.logged[material] || {})[String(mm)] || 0
    const parts = [`This is the middle of what people logged. 8 in 10 jobs on comparable stock ran between ${fmt(speed / law.high)} and ${fmt(speed / law.low)} mm/s at this power.`]
    if (mm > law.thickest[material] + 1) parts.push(`Thicker than any ${material.toLowerCase()} job in the fit (${law.thickest[material]} mm), so this is a guess past the data.`)
    if (speed < 4) parts.push("Few logged jobs run slower than 4 mm/s. Raise power if you can, and test first.")
    parts.push(logged ? `${logged} real jobs are logged at this exact thickness; check Find a setting.` : "Nothing is logged at this thickness, so test on scrap.")
    this.noteTarget.textContent = parts.join(" ")
  }
}
