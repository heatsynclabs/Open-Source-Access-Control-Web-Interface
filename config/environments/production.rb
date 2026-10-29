Dooraccess::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests, and is loaded once at boot
  config.cache_classes = true
  config.eager_load = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Puma serves public/ and the precompiled assets itself (no Apache or nginx
  # in front; Traefik only proxies)
  config.public_file_server.enabled = true

  # No minifiers: the Sass-based CSS compressor cannot parse modern CSS such as
  # max(var(--space-4), var(--safe-l)) in the GANTRY theme and aborts the
  # precompile. Cloudflare compresses responses in transit.
  # Dart Sass writes compressed CSS itself; nothing re-parses it afterwards.
  config.sass.style = :compressed
  config.assets.css_compressor = nil
  config.assets.js_compressor = nil

  # Fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = false

  # Generate digests for assets URLs
  config.assets.digest = true

  # Defaults to Rails.root.join("public/assets")
  # config.assets.manifest = YOUR_PATH

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # See everything in the log (default is :info)
  config.log_level = :info

  # Prepend all log lines with the following tags
  # config.log_tags = [ :subdomain, :uuid ]

  # Log to stdout so Coolify shows the logs and they survive redeploys
  config.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new($stdout))

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  # config.assets.precompile += %w( search.js )

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  # config.active_record.auto_explain_threshold_in_seconds = 0.5
  
  config.action_mailer.default_url_options = { :host => 'members.heatsynclabs.org', :protocol => 'https' }

  # hsl-web's Apache sent this on every members response; keep it so anything
  # reading the site from another origin keeps working. (Cloudflare rewrites
  # it for space_api.json.)
  config.action_dispatch.default_headers.merge!("Access-Control-Allow-Origin" => "*")
end
