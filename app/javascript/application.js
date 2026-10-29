// Entry point for the import map (config/importmap.rb).
import { Turbo } from "@hotwired/turbo-rails"
import "controllers"

// Pages load normally. Turbo is here only for its frames, which fill in slow
// panels (the calendar card) after the page has drawn. Turbo Drive would
// also take over every link and form, and jquery_ujs already handles the
// sign out and delete links, so it stays off.
Turbo.session.drive = false
