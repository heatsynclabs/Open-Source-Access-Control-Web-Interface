#!/bin/bash
set -e
cd /app
# Render runtime config from environment variables (Coolify-managed), falling
# back to the committed docker defaults when a var is unset. No secrets in git.
ruby -ryaml -e '
p="config/config.yml"; c=YAML.load_file(p)
%w[development test production].each do |e|
  next unless c[e]
  c[e]["door_access_url"]=ENV["DOOR_ACCESS_URL"] if ENV["DOOR_ACCESS_URL"].to_s!=""
  c[e]["door_access_password"]=ENV["DOOR_ACCESS_PASSWORD"] if ENV["DOOR_ACCESS_PASSWORD"].to_s!=""
  c[e]["smtp_address"]=ENV["SMTP_ADDRESS"] if ENV["SMTP_ADDRESS"].to_s!=""
  c[e]["smtp_port"]=ENV["SMTP_PORT"].to_i if ENV["SMTP_PORT"].to_s!=""
  c[e]["smtp_tls"]=(ENV["SMTP_TLS"]=="true") if ENV["SMTP_TLS"].to_s!=""
  c[e]["smtp_domain"]=ENV["SMTP_DOMAIN"] if ENV["SMTP_DOMAIN"].to_s!=""
  c[e]["smtp_authentication"]=ENV["SMTP_AUTHENTICATION"] if ENV["SMTP_AUTHENTICATION"].to_s!=""
  c[e]["smtp_user"]=ENV["SMTP_USER"] if ENV["SMTP_USER"].to_s!=""
  c[e]["smtp_password"]=ENV["SMTP_PASSWORD"] if ENV["SMTP_PASSWORD"].to_s!=""
end
File.write(p,c.to_yaml)
'
exec bash /app/docker-run.sh
