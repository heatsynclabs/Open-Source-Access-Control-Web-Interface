require_relative "boot"

# Only the frameworks this app uses. "rails/all" also loads Active Storage,
# which refuses to boot in production without a config/storage.yml; the app
# stores files with Paperclip on S3 instead.
require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"
require "sprockets/railtie"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Dooraccess
  class Application < Rails::Application
    config.load_defaults 7.2
    config.time_zone = 'America/Phoenix'

    config.autoload_lib(ignore: %w[assets tasks])

    # This app predates Rails 5's required-by-default belongs_to. Its legacy
    # data (and optional associations like User#oriented_by) rely on the old
    # behavior where belongs_to is optional unless explicitly required.
    config.active_record.belongs_to_required_by_default = false

    config.encoding = "utf-8" # TODO: still needed?
    config.filter_parameters += [:password, :pass] # TODO: still needed?
    # config.active_record.whitelist_attributes = true # TODO: still needed?
  end
end
