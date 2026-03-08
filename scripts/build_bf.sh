#!/usr/bin/env bash
# Build BrainFuck sources to executables using bf2c + gcc
# Usage: ./build_bf.sh [program.bf ...]
# If no args, builds the named SQLite demo programs.
#
# Env:
#   BF2C     - bf2c binary (default: bf2c)
#   GCC      - gcc binary (default: gcc)
#   CFLAGS   - gcc flags for smaller programs (default: -O2).
#              Larger generated programs use -O0 by default (huge C can segfault gcc at -O2).
set -euo pipefail

BF2C="${BF2C:-bf2c}"
BF2C_FLAGS="${BF2C_FLAGS:--F}"
GCC="${GCC:-gcc}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BF_DIR="$PROJECT_DIR/bf"

generate_known_bf() {
  local phase="$1"

  case "$phase" in
    sqlite_header_parser)
      [ -f "$SCRIPT_DIR/gen_sqlite_header_parser_bf.py" ] && python3 "$SCRIPT_DIR/gen_sqlite_header_parser_bf.py" > "$BF_DIR/$phase.bf" 2>/dev/null || true
      ;;
    sqlite_page1_parser)
      [ -f "$SCRIPT_DIR/gen_sqlite_page1_parser_bf.py" ] && python3 "$SCRIPT_DIR/gen_sqlite_page1_parser_bf.py" > "$BF_DIR/$phase.bf" 2>/dev/null || true
      ;;
    sqlite_schema_walk)
      [ -f "$SCRIPT_DIR/gen_sqlite_schema_walk_bf.py" ] && python3 "$SCRIPT_DIR/gen_sqlite_schema_walk_bf.py" > "$BF_DIR/$phase.bf" 2>/dev/null || true
      ;;
    sqlite_table_scan)
      [ -f "$SCRIPT_DIR/gen_sqlite_table_scan_bf.py" ] && python3 "$SCRIPT_DIR/gen_sqlite_table_scan_bf.py" > "$BF_DIR/$phase.bf" 2>/dev/null || true
      ;;
    sqlite_insert)
      [ -f "$SCRIPT_DIR/gen_insert_bf.py" ] && python3 "$SCRIPT_DIR/gen_insert_bf.py" > "$BF_DIR/$phase.bf" 2>/dev/null || true
      ;;
    sqlite_update)
      [ -f "$SCRIPT_DIR/gen_update_bf.py" ] && python3 "$SCRIPT_DIR/gen_update_bf.py" > "$BF_DIR/$phase.bf" 2>/dev/null || true
      ;;
    sqlite_delete)
      [ -f "$SCRIPT_DIR/gen_delete_bf.py" ] && python3 "$SCRIPT_DIR/gen_delete_bf.py" > "$BF_DIR/$phase.bf" 2>/dev/null || true
      ;;
    sqlite_create_log_table)
      [ -f "$SCRIPT_DIR/gen_create_table_bf.py" ] && python3 "$SCRIPT_DIR/gen_create_table_bf.py" log ts:INT value:TEXT > "$BF_DIR/$phase.bf" 2>/dev/null || true
      ;;
    sqlite_select_users_name)
      [ -f "$SCRIPT_DIR/gen_select_bf.py" ] && python3 "$SCRIPT_DIR/gen_select_bf.py" users name > "$BF_DIR/$phase.bf" 2>/dev/null || true
      ;;
    sqlite_select_users_name_sex)
      [ -f "$SCRIPT_DIR/gen_select_bf.py" ] && python3 "$SCRIPT_DIR/gen_select_bf.py" users name sex > "$BF_DIR/$phase.bf" 2>/dev/null || true
      ;;
  esac
}

phase_cflags() {
  local phase="$1"

  case "$phase" in
    sqlite_header_inspector|sqlite_header_parser|sqlite_page1_parser)
      printf '%s\n' "${CFLAGS:--O2}"
      ;;
    sqlite_schema_walk|sqlite_table_scan|sqlite_insert|sqlite_update|sqlite_delete|sqlite_create_log_table|sqlite_select_users_name|sqlite_select_users_name_sex)
      printf '%s\n' "-O0"
      ;;
    *)
      printf '%s\n' "${CFLAGS:--O2}"
      ;;
  esac
}

build_phase_if_present() {
  local phase="$1"
  local bf="$BF_DIR/$phase.bf"

  generate_known_bf "$phase"
  [ -f "$bf" ] && build_one "$bf" "$(phase_cflags "$phase")" || true
}

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
    local_phase="$(basename "${bf%.bf}")"
    case "$local_phase" in
      sqlite_*)
        generate_known_bf "$local_phase"
        if [ -f "$bf" ]; then
          build_one "$bf" "$(phase_cflags "$local_phase")"
        elif [ -f "$BF_DIR/$local_phase.bf" ]; then
          build_one "$BF_DIR/$local_phase.bf" "$(phase_cflags "$local_phase")"
        else
          echo "BrainFuck source not found: $bf"
          exit 1
        fi
        ;;
      *)
        build_one "$bf"
        ;;
    esac
  done
else
  build_phase_if_present sqlite_header_inspector
  build_phase_if_present sqlite_header_parser
  build_phase_if_present sqlite_page1_parser
  build_phase_if_present sqlite_schema_walk
  build_phase_if_present sqlite_table_scan
  build_phase_if_present sqlite_insert
  build_phase_if_present sqlite_update
  build_phase_if_present sqlite_delete
  build_phase_if_present sqlite_create_log_table
  build_phase_if_present sqlite_select_users_name
  build_phase_if_present sqlite_select_users_name_sex
fi
