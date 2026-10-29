// Chart.js and Chartkick, themed from the GANTRY tokens so charts follow
// light and dark mode. Imported only by pages that draw a chart (see
// ChartCardComponent).
import "Chart.bundle"
import "chartkick"

// Series colours in a fixed order. Each theme has its own steps, checked
// with the dataviz palette validator against that theme's card surface
// (lightness band, chroma, colour-blind separation). The first is the GANTRY
// amber; one-series charts use it.
const PALETTES = {
  light: ["#c98714", "#3a7bc8", "#2f9a6a", "#8a5cd0", "#d0502a"],
  dark: ["#c08214", "#4a86d0", "#33a06f", "#9468d8", "#d65a32"],
}

function token(name) {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim()
}

function theme() {
  return document.documentElement.dataset.theme === "dark" ? "dark" : "light"
}

function applyTheme() {
  const defaults = window.Chart.defaults
  defaults.color = token("--ash")
  defaults.borderColor = token("--chart-grid")
  defaults.font.family = token("--font-ui")
  defaults.font.size = 11
  defaults.plugins.tooltip.backgroundColor = token("--bone")
  defaults.plugins.tooltip.titleColor = token("--char")
  defaults.plugins.tooltip.bodyColor = token("--char")
  defaults.plugins.tooltip.cornerRadius = 0
  defaults.plugins.legend.labels.boxWidth = 12
  window.Chartkick.options = { ...window.Chartkick.options, thousands: "," }
}

// A chart's colours from the theme palette. A chart whose series stand for
// fixed things (calendar categories) passes paletteOrder, the palette slot
// for each series, so a category keeps its colour on every chart.
function colorsFor(options, data) {
  const palette = PALETTES[theme()]
  if (options.paletteOrder) return options.paletteOrder.map((slot) => palette[slot])
  // One series: Chartkick would give each bar its own colour, so pass one.
  const multiSeries = Array.isArray(data) && data.length > 0 && data[0] && data[0].data !== undefined
  return multiSeries ? palette : [palette[0]]
}

// Draws every chart again with the current theme. Charts that set their own
// colours keep them.
function redrawAll() {
  window.Chartkick.eachChart((chart) => {
    const options = chart.getOptions()
    if (options.colors && !options.themeColors) return chart.redraw()
    const data = chart.getDataSource()
    chart.updateData(data, { ...options, colors: colorsFor(options, data), themeColors: true })
  })
}

applyTheme()
redrawAll()

window.addEventListener("theme:change", () => {
  applyTheme()
  redrawAll()
})
