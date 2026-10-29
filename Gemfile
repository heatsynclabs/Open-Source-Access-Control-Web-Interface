source 'https://rubygems.org'

ruby '3.3.5'

gem 'rails', '~> 7.2'
gem 'dotenv-rails'

# App server (dev and production). Rails 7 no longer ships a default server.
gem 'puma'

gem 'pg'

# Pin json to the 2.x line: activesupport 7.2's cookie/message serializer
# still passes quirks_mode: true, which json 3.1+ removed (breaks every
# response that writes a session cookie).
gem 'json', '~> 2.7'

# Asset pipeline. In Rails 7 these must live in the default group so
# Bundler.require loads Sprockets::Railtie; the Rails 3.2 ":assets" group
# is no longer auto-required, which left the pipeline dormant.
gem 'sprockets-rails'
# Dart Sass (through sass-embedded) instead of the retired LibSass, so modern
# CSS (hsl(var()), max(), color-mix(), container queries) compiles as written.
gem 'dartsass-sprockets', '~> 3.2'

# JavaScript without a Node build: import maps, Stimulus controllers, and Turbo
# Frames for lazily loaded panels (Turbo Drive is switched off in JS).
gem 'importmap-rails', '~> 2.2'
gem 'stimulus-rails', '~> 1.3'
gem 'turbo-rails', '~> 2.0'

# UI building blocks.
gem 'view_component', '~> 4.0'
gem 'lucide-rails', '~> 0.7'

# Charts (Chart.js, vendored by the gem) and time-zone-aware SQL grouping.
gem 'chartkick', '~> 5.3'
gem 'groupdate', '~> 6.8'

# The lab calendar: parse Google's public ICS feed, expand repeating events,
# and lay them out in month and week grids.
gem 'icalendar', '~> 2.13'
gem 'icalendar-recurrence', '~> 1.2'
gem 'simple_calendar', '~> 3.1'

# Asset compilation uses the Node runtime (installed in the Docker image)
# via execjs. therubyracer/libv8 no longer build on modern toolchains.
gem 'uglifier'

gem 'jquery-rails'

gem 'devise'

# cancancan is the maintained successor to the abandoned cancan gem and keeps
# the same CanCan API (Ability, load_and_authorize_resource, can?, authorize!).
gem 'cancancan', '~> 3.5'

# To use ActiveModel has_secure_password
gem 'bcrypt'

# kt-paperclip is the maintained fork of the retired paperclip gem; S3 storage
# uses aws-sdk-s3.
gem 'kt-paperclip', '~> 7.2'
gem 'aws-sdk-s3'
gem 'gravtastic'

gem 'passenger'

gem 'rails-settings-cached'

group :test do
  # Rails 7.2's test runner does not support Minitest 6 yet.
  gem 'minitest', '~> 5.25'
end
