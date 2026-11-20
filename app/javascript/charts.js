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

// The bucket we are in is not over yet: the server ends its label with
// " (so far)" (Analytics::Period::SO_FAR). Its line segment is dashed and its
// bars paler, so a half-counted month does not read as a drop.
const SO_FAR = " (so far)"

function paler(color) {
  const hex = /^#([0-9a-f]{6})$/i.exec(color || "")
  if (!hex) return color
  const n = parseInt(hex[1], 16)
  return `rgba(${n >> 16}, ${(n >> 8) & 255}, ${n & 255}, 0.4)`
}

const unfinishedPeriod = {
  id: "unfinishedPeriod",
  beforeUpdate(chart) {
    const labels = chart.data.labels || []
    const last = labels.length - 1
    if (last < 0 || !String(labels[last]).endsWith(SO_FAR)) return
    chart.data.datasets.forEach((dataset) => {
      if ((dataset.type || chart.config.type) === "line") {
        dataset.segment = { borderDash: (ctx) => (ctx.p1DataIndex === last ? [5, 4] : undefined) }
      } else {
        const base = Array.isArray(dataset.backgroundColor) ? dataset.backgroundColor[0] : dataset.backgroundColor
        dataset.backgroundColor = labels.map((_label, i) => (i === last ? paler(base) : base))
      }
    })
  },
}
window.Chart.register(unfinishedPeriod)

applyTheme()
redrawAll()

window.addEventListener("theme:change", () => {
  applyTheme()
  redrawAll()
})

// Chartkick draws a page's charts when their inline scripts run, which can
// be after this module, so theme them again once the page has loaded.
// Charts drawn later inside a Turbo Frame (the profile's Door stats tab)
// take the theme too.
if (document.readyState === "complete") redrawAll()
else window.addEventListener("load", redrawAll)
document.addEventListener("turbo:frame-load", redrawAll)
