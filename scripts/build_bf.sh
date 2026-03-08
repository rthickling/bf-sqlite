#!/usr/bin/env bash
# Build BrainFuck sources to executables using bf2c + gcc
# Usage: ./build_bf.sh [program.bf ...]
# If no args, builds phases 1–8.
#
# Env:
#   BF2C     - bf2c binary (default: bf2c)
#   GCC      - gcc binary (default: gcc)
#   CFLAGS   - gcc flags for phases 1–3 (default: -O2).
#              Phases 4–8 use -O0 by default (huge C can segfault gcc at -O2).
set -euo pipefail

BF2C="${BF2C:-bf2c}"
BF2C_FLAGS="${BF2C_FLAGS:--F}"
GCC="${GCC:-gcc}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BF_DIR="$PROJECT_DIR/bf"

build_one() {
  local bf="$1"
  local cflags="${2:-${CFLAGS:--O2}}"
  local base="${bf%.bf}"
  local c="${base}.c"
  local exe="$(basename "$base")"
  echo "Building $bf -> $exe"
  "$BF2C" $BF2C_FLAGS -o "$c" "$bf"
  $GCC $cflags -o "$PROJECT_DIR/$exe" "$c"
  echo "  -> $PROJECT_DIR/$exe"
}

if [ $# -gt 0 ]; then
  for bf in "$@"; do
    build_one "$bf"
  done
else
  build_one "$BF_DIR/phase1_header_inspector.bf"
  # Phase 2: regenerate BF then build
  if [ -f "$SCRIPT_DIR/gen_phase2_bf.py" ]; then
    python3 "$SCRIPT_DIR/gen_phase2_bf.py" > "$BF_DIR/phase2_header_parser.bf" 2>/dev/null || true
  fi
  [ -f "$BF_DIR/phase2_header_parser.bf" ] && build_one "$BF_DIR/phase2_header_parser.bf" || true
  # Phase 3: regenerate BF then build
  if [ -f "$SCRIPT_DIR/gen_phase3_bf.py" ]; then
    python3 "$SCRIPT_DIR/gen_phase3_bf.py" > "$BF_DIR/phase3_page1_parser.bf" 2>/dev/null || true
  fi
  [ -f "$BF_DIR/phase3_page1_parser.bf" ] && build_one "$BF_DIR/phase3_page1_parser.bf" || true
  # Phase 4: schema walker
  if [ -f "$SCRIPT_DIR/gen_phase4_bf.py" ]; then
    python3 "$SCRIPT_DIR/gen_phase4_bf.py" > "$BF_DIR/phase4_schema_walk.bf" 2>/dev/null || true
  fi
  [ -f "$BF_DIR/phase4_schema_walk.bf" ] && build_one "$BF_DIR/phase4_schema_walk.bf" "-O0" || true
  # Phase 5: table scan (-O0 to avoid gcc segfault on huge C)
  if [ -f "$SCRIPT_DIR/gen_phase5_bf.py" ]; then
    python3 "$SCRIPT_DIR/gen_phase5_bf.py" > "$BF_DIR/phase5_table_scan.bf" 2>/dev/null || true
  fi
  [ -f "$BF_DIR/phase5_table_scan.bf" ] && build_one "$BF_DIR/phase5_table_scan.bf" "-O0" || true
  # Phase 6: INSERT (add row to users)
  if [ -f "$SCRIPT_DIR/gen_insert_bf.py" ]; then
    python3 "$SCRIPT_DIR/gen_insert_bf.py" > "$BF_DIR/phase6_insert.bf" 2>/dev/null || true
  fi
  [ -f "$BF_DIR/phase6_insert.bf" ] && build_one "$BF_DIR/phase6_insert.bf" "-O0" || true
  # Phase 7: UPDATE (jude -> judy in row 4)
  if [ -f "$SCRIPT_DIR/gen_update_bf.py" ]; then
    python3 "$SCRIPT_DIR/gen_update_bf.py" > "$BF_DIR/phase7_update.bf" 2>/dev/null || true
  fi
  [ -f "$BF_DIR/phase7_update.bf" ] && build_one "$BF_DIR/phase7_update.bf" "-O0" || true
  # Phase 8: DELETE (remove row 4 from users)
  if [ -f "$SCRIPT_DIR/gen_delete_bf.py" ]; then
    python3 "$SCRIPT_DIR/gen_delete_bf.py" > "$BF_DIR/phase8_delete.bf" 2>/dev/null || true
  fi
  [ -f "$BF_DIR/phase8_delete.bf" ] && build_one "$BF_DIR/phase8_delete.bf" "-O0" || true
fi
