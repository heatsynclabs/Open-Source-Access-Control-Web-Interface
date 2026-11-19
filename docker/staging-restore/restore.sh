#!/bin/sh
# Staging database refresh, run by docker-compose.staging.yml on every deploy.
#
# Production is never contacted. The R610 writes a dump of the production
# members database every night at 02:00 (/data/backups/offsite/members, see
# docs/22 in the operations folder). This loads the newest complete one into
# the staging database, replacing whatever staging had.
#
# STAGING_DB_REFRESH=off keeps the current staging data instead.
set -eu

export PGHOST="${PGHOST:-staging-db}" PGUSER=members PGPASSWORD="$POSTGRES_PASSWORD"
BACKUPS=/backups

until pg_isready -q -d postgres; do sleep 2; done

has_data() {
  [ "$(psql -d members -tAc 'SELECT count(*) FROM users' 2>/dev/null || echo 0)" -gt 0 ]
}

if [ "${STAGING_DB_REFRESH:-on}" = "off" ]; then
  echo "staging restore: STAGING_DB_REFRESH=off, keeping the current data"
  exit 0
fi

# Newest first; skip a dump that is still being written or is damaged.
dump=""
for f in $(ls -1t "$BACKUPS"/members-*.sql.gz 2>/dev/null); do
  if gzip -t "$f" 2>/dev/null; then dump="$f"; break; fi
  echo "staging restore: skipping $f (not a complete gzip file)"
done

if [ -z "$dump" ]; then
  if has_data; then
    echo "staging restore: no backup found in $BACKUPS, keeping the current data"
    exit 0
  fi
  echo "staging restore: no backup found in $BACKUPS and the staging database is empty" >&2
  exit 1
fi

echo "staging restore: loading $(basename "$dump")"
# The dump creates and connects to the members database itself. FORCE ends
# the connections of the staging site still running from the last deploy.
psql -q -d postgres -v ON_ERROR_STOP=1 -c 'DROP DATABASE IF EXISTS members WITH (FORCE)'
gunzip -c "$dump" | psql -q -d postgres -v ON_ERROR_STOP=1 >/dev/null

users=$(psql -d members -tAc 'SELECT count(*) FROM users')
last=$(psql -d members -tAc 'SELECT max(created_at) FROM door_logs')
echo "staging restore: done, $users users, newest door log row $last"
