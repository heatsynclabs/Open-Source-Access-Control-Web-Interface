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

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails'
  gem 'coffee-rails'

  # Asset compilation uses the Node runtime (installed in the Docker image)
  # via execjs. therubyracer/libv8 no longer build on modern toolchains.
  gem 'uglifier'
end

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
