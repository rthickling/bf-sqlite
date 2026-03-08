#!/usr/bin/env bash
# Create tests/fixtures/tiny.db using sqlite3 (optional, for full testing)
# Run after installing sqlite3: ./scripts/make_test_db.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DB="$PROJECT_DIR/tests/fixtures/tiny.db"
SQL="$PROJECT_DIR/tests/fixtures/tiny.sql.txt"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3 not found. Install it to create a real test DB, e.g.:"
  echo "  sudo apt install sqlite3"
  exit 1
fi

mkdir -p "$(dirname "$DB")"
sqlite3 "$DB" < "$SQL"
echo "Created $DB"
sqlite3 "$DB" "SELECT * FROM users;"
