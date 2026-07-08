#!/usr/bin/env bash
# Runs INSIDE the dev container, in a worktree's mlai/ dir, under `mise x` so
# POSTGRES_* are resolved from that worktree's .dev.env (RDEV_DB_SUFFIX-suffixed).
# Creates + migrates the worktree's isolated mlai dev database.
#
# Why mlai needs this and railsapi doesn't: rails' own `parallel:setup` creates
# whatever DB name database.yml resolves to. mlai has no separate test DB (tests
# reuse the dev DB with transaction rollback) and its DB is only ever created
# once by docker-compose. So each suffixed worktree needs its dev DB created and
# migrated to that worktree's alembic head.
#
# Elasticsearch indices live on the shared mlai ES instance (NOT per-postgres-DB),
# so mainline already created them — we intentionally do NOT re-init ES here.
# This mirrors mlai/src/scripts/init_db.py minus _init_elasticsearch().
set -euo pipefail

: "${POSTGRES_DB:?POSTGRES_DB not set (is this a worktree mlai dir under mise?)}"
: "${POSTGRES_USER:?}"; : "${POSTGRES_PORT:?}"; : "${POSTGRES_PASSWORD:?}"
export PGPASSWORD="$POSTGRES_PASSWORD"
H=localhost

if [ "$POSTGRES_DB" = "rhythms_mlai_development" ]; then
  echo "  mlai: no RDEV_DB_SUFFIX set -> mainline DB, nothing to isolate"
  exit 0
fi

# create-if-missing (createdb errors harmlessly if it already exists)
if createdb -h "$H" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" "$POSTGRES_DB" 2>/dev/null; then
  echo "  mlai: created DB $POSTGRES_DB"
else
  echo "  mlai: DB $POSTGRES_DB already present"
fi

# phoenix schema + widened alembic_version (long revision IDs) must exist before
# migrations run — copied verbatim from init_db.py's _init_db().
psql -h "$H" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -q \
  -c "CREATE SCHEMA IF NOT EXISTS phoenix" \
  -c "CREATE TABLE IF NOT EXISTS alembic_version (version_num VARCHAR(256) NOT NULL, CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num))"

echo "  mlai: alembic upgrade head ..."
poetry run alembic upgrade head
echo "  mlai: $POSTGRES_DB ready"
