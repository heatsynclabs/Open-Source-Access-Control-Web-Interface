# Browser modules, served by the asset pipeline without a Node build step.

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Charts load only on pages that draw one (see ChartCardComponent).
pin "charts", preload: false
pin "chartkick", to: "chartkick.js", preload: false
pin "Chart.bundle", to: "Chart.bundle.js", preload: false
