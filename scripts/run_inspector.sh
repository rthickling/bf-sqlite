#!/usr/bin/env bash
# run_inspector.sh - Run SQLite header inspector against a DB
# Starts pager, connects BF inspector via FIFOs
set -euo pipefail

DB="${1:?Usage: $0 <database.db>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INSPECTOR="${INSPECTOR:-$PROJECT_DIR/sqlite_header_inspector}"
cd "$PROJECT_DIR"

# Backward-compatible fallback for older naming.
if [ ! -x "$INSPECTOR" ] && [ -x "$PROJECT_DIR/inspector" ]; then
  INSPECTOR="$PROJECT_DIR/inspector"
fi

exec "$SCRIPT_DIR/run_bf_db.sh" "$INSPECTOR" "$DB"
