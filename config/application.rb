require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Dooraccess
  class Application < Rails::Application
    config.load_defaults 7.2
    config.time_zone = 'America/Phoenix'

    config.autoload_lib(ignore: %w[assets tasks])

    config.encoding = "utf-8" # TODO: still needed?
    config.filter_parameters += [:password, :pass] # TODO: still needed?
    # config.active_record.whitelist_attributes = true # TODO: still needed?
  end
end
