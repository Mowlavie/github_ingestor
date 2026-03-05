#!/bin/bash
set -e

echo "==> Preparing database..."
bundle exec rails db:create 2>/dev/null || true
bundle exec rails db:migrate

echo "==> Starting: $@"
exec "$@"
