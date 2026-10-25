FROM ruby:3.3.5-slim

# System deps: build tools for native gems (pg, bcrypt, passenger),
# imagemagick for Paperclip, node as the JS runtime for execjs (replaces
# therubyracer), postgres client headers, git and curl.
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    imagemagick \
    nodejs \
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

# Copy example Docker configs and generate a random secret_key_base
# (Rails 7 replaced the old secret_token). .env is handled by ENV in compose.
RUN cp config/database.yml.docker config/database.yml &&\
    cp config/config.yml.docker config/config.yml &&\
    echo "Rails.application.config.secret_key_base = \"$(tr -dc A-Za-z0-9 </dev/urandom | head -c 64; echo)\"" > config/initializers/secret_token.rb

EXPOSE 3000
CMD ["bash", "/app/docker-entrypoint.sh"]
