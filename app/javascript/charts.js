// Chart.js and Chartkick, themed from the GANTRY tokens so charts follow
// light and dark mode. Imported only by pages that draw a chart.
import "Chart.bundle"
import "chartkick"

function token(name) {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim()
}

function applyTheme() {
  const Chart = window.Chart
  Chart.defaults.color = token("--ash")
  Chart.defaults.borderColor = token("--chart-grid")
  Chart.defaults.font.family = token("--font-ui")
  Chart.defaults.font.size = 11
  Chart.defaults.plugins.tooltip.backgroundColor = token("--bone")
  Chart.defaults.plugins.tooltip.titleColor = token("--char")
  Chart.defaults.plugins.tooltip.bodyColor = token("--char")
  Chart.defaults.plugins.tooltip.cornerRadius = 0
  Chart.defaults.plugins.legend.labels.boxWidth = 12
}

// Charts that drew before this ran pick up the theme on a redraw.
applyTheme()
window.Chartkick.eachChart((chart) => chart.redraw())

// Redraw every chart in the new colours when the theme flips.
window.addEventListener("theme:change", () => {
  applyTheme()
  window.Chartkick.eachChart((chart) => chart.redraw())
})
