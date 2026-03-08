#!/usr/bin/env bash
# Build BrainFuck sources to executables using bf2c + gcc
# Usage: ./build_bf.sh [program.bf ...]
# If no args, builds phases 1–9.
#
# Env:
#   BF2C     - bf2c binary (default: bf2c)
#   GCC      - gcc binary (default: gcc)
#   CFLAGS   - gcc flags for phases 1–3 (default: -O2).
#              Phases 4–9 use -O0 by default (huge C can segfault gcc at -O2).
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
    phase2_header_parser)
      [ -f "$SCRIPT_DIR/gen_phase2_bf.py" ] && python3 "$SCRIPT_DIR/gen_phase2_bf.py" > "$BF_DIR/$phase.bf" 2>/dev/null || true
      ;;
    phase3_page1_parser)
      [ -f "$SCRIPT_DIR/gen_phase3_bf.py" ] && python3 "$SCRIPT_DIR/gen_phase3_bf.py" > "$BF_DIR/$phase.bf" 2>/dev/null || true
      ;;
    phase4_schema_walk)
      [ -f "$SCRIPT_DIR/gen_phase4_bf.py" ] && python3 "$SCRIPT_DIR/gen_phase4_bf.py" > "$BF_DIR/$phase.bf" 2>/dev/null || true
      ;;
    phase5_table_scan)
      [ -f "$SCRIPT_DIR/gen_phase5_bf.py" ] && python3 "$SCRIPT_DIR/gen_phase5_bf.py" > "$BF_DIR/$phase.bf" 2>/dev/null || true
      ;;
    phase6_insert)
      [ -f "$SCRIPT_DIR/gen_insert_bf.py" ] && python3 "$SCRIPT_DIR/gen_insert_bf.py" > "$BF_DIR/$phase.bf" 2>/dev/null || true
      ;;
    phase7_update)
      [ -f "$SCRIPT_DIR/gen_update_bf.py" ] && python3 "$SCRIPT_DIR/gen_update_bf.py" > "$BF_DIR/$phase.bf" 2>/dev/null || true
      ;;
    phase8_delete)
      [ -f "$SCRIPT_DIR/gen_delete_bf.py" ] && python3 "$SCRIPT_DIR/gen_delete_bf.py" > "$BF_DIR/$phase.bf" 2>/dev/null || true
      ;;
    phase9_select_users_name)
      [ -f "$SCRIPT_DIR/gen_select_bf.py" ] && python3 "$SCRIPT_DIR/gen_select_bf.py" users name > "$BF_DIR/$phase.bf" 2>/dev/null || true
      ;;
    phase9_select_users_name_sex)
      [ -f "$SCRIPT_DIR/gen_select_bf.py" ] && python3 "$SCRIPT_DIR/gen_select_bf.py" users name sex > "$BF_DIR/$phase.bf" 2>/dev/null || true
      ;;
  esac
}

phase_cflags() {
  local phase="$1"

  case "$phase" in
    phase1_*|phase2_*|phase3_*)
      printf '%s\n' "${CFLAGS:--O2}"
      ;;
    phase4_*|phase5_*|phase6_*|phase7_*|phase8_*|phase9_*)
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
      phase[1-9]*)
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
  build_phase_if_present phase1_header_inspector
  build_phase_if_present phase2_header_parser
  build_phase_if_present phase3_page1_parser
  build_phase_if_present phase4_schema_walk
  build_phase_if_present phase5_table_scan
  build_phase_if_present phase6_insert
  build_phase_if_present phase7_update
  build_phase_if_present phase8_delete
  build_phase_if_present phase9_select_users_name
  build_phase_if_present phase9_select_users_name_sex
fi
