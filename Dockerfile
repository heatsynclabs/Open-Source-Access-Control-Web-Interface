FROM ruby:3.3.5-slim

# System deps: build tools for native gems (pg, bcrypt, passenger),
# imagemagick for Paperclip, postgres client headers, git and curl. No Node:
# JavaScript is served through import maps and needs no build.
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    imagemagick \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install gems first so code changes do not bust the bundle cache layer.
# Copy the lock too so the install is deterministic and matches the committed
# versions (COPY . below restores the same lock).
COPY Gemfile Gemfile.lock /app/
RUN gem install bundler -v 2.5.19 && bundle install

COPY . /app

# Copy example Docker configs. secret_key_base (Rails 7 replaced the old
# secret_token) comes from SECRET_KEY_BASE when set, so sessions survive
# rebuilds; otherwise a random one generated here. .env is handled by ENV in
# compose.
RUN cp config/database.yml.docker config/database.yml &&\
    cp config/config.yml.docker config/config.yml &&\
    printf 'Rails.application.config.secret_key_base = ENV.fetch("SECRET_KEY_BASE") { "%s" }\n' "$(tr -dc A-Za-z0-9 </dev/urandom | head -c 64)" > config/initializers/secret_token.rb

# Precompile assets for production (development compiles them on request).
RUN RAILS_ENV=production bundle exec rails assets:precompile

EXPOSE 3000
CMD ["bash", "/app/docker-entrypoint.sh"]
