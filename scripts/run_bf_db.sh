#!/usr/bin/env bash
# run_bf_db.sh - Run a BrainFuck program with SQLite database access
#
# Usage: ./run_bf_db.sh <program.bf|program> <database.db>
#
# If given a .bf file, compiles it with bf2c + a C compiler first.
# If given a missing phase executable (e.g. ./phase5_table_scan), tries to
# build the project phases automatically.
# If tests/fixtures/tiny.db is requested and missing, tries to create it from
# tests/fixtures/tiny.sql.txt when sqlite3 is available.
# Connects the program to the pager via FIFOs: program stdout -> pager, pager -> program stdin.
#
# Examples:
#   ./run_bf_db.sh examples/01_hello_header.bf tests/fixtures/tiny.db
#   ./run_bf_db.sh ./phase5_table_scan tests/fixtures/tiny.db
#
set -euo pipefail

BF="${1:?Usage: $0 <program.bf|program> <database.db>}"
DB="${2:?Usage: $0 <program.bf|program> <database.db>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REQ="${REQ:-/tmp/bf_sqlite_req.$$}"
RES="${RES:-/tmp/bf_sqlite_res.$$}"
BF2C_FLAGS="${BF2C_FLAGS:--F}"

cd "$PROJECT_DIR"

ensure_db() {
  local db="$1"
  local tiny_db="$PROJECT_DIR/tests/fixtures/tiny.db"
  local tiny_sql="$PROJECT_DIR/tests/fixtures/tiny.sql.txt"

  [ -f "$db" ] && return 0

  case "$db" in
    "$tiny_db"|tests/fixtures/tiny.db|./tests/fixtures/tiny.db)
      if [ -f "$tiny_sql" ]; then
        if command -v sqlite3 >/dev/null 2>&1; then
          echo "Creating $db from $tiny_sql..."
          mkdir -p "$(dirname "$db")"
          sqlite3 "$db" < "$tiny_sql"
          return 0
        fi
        echo "Database not found: $db"
        echo "sqlite3 is required to create the test fixture automatically."
        exit 1
      fi
      ;;
  esac
}

ensure_exe() {
  local exe="$1"
  local base
  base="$(basename "$exe")"

  [ -x "$exe" ] && return 0

  case "$base" in
    phase[1-8]*)
      if [ -x "$SCRIPT_DIR/build_bf.sh" ]; then
        echo "Building project phase executables..."
        "$SCRIPT_DIR/build_bf.sh"
      fi
      ;;
  esac
}

# Build .bf to executable if needed
if [[ "$BF" == *.bf ]]; then
  EXE="${PROJECT_DIR}/$(basename "$BF" .bf)"
  C_FILE="${BF%.bf}.c"
  if [ ! -x "$EXE" ] || [ "$BF" -nt "$EXE" ]; then
    if ! command -v "${BF2C:-bf2c}" >/dev/null 2>&1; then
      echo "bf2c not found. Build the .bf manually or set BF2C."
      exit 1
    fi
    echo "Building $BF..."
    "${BF2C:-bf2c}" $BF2C_FLAGS -o "$C_FILE" "$BF"
    ${GCC:-gcc} -O2 -o "$EXE" "$C_FILE"
  fi
else
  EXE="$BF"
  ensure_exe "$EXE"
fi

ensure_db "$DB"
[ -x "$EXE" ] || { echo "Executable not found: $EXE"; exit 1; }
[ -f "$DB" ] || { echo "Database not found: $DB"; exit 1; }

exec python3 "$SCRIPT_DIR/run_bf_db.py" "$SCRIPT_DIR/pager.sh" "$EXE" "$DB"
