#!/usr/bin/env bash
# run_example.sh - Run a BrainFuck example with pager
# Usage: ./run_example.sh examples/reference/hello_schema.bf path/to/db
set -euo pipefail

BF="${1:?Usage: $0 <program.bf> <database.db>}"
DB="${2:?Usage: $0 <program.bf> <database.db>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "$SCRIPT_DIR/run_bf_db.sh" "$BF" "$DB"
