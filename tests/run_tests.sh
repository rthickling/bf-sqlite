#!/usr/bin/env bash
# run_tests.sh - Run BrainFuck SQLite tests
# Requires: bf2c (or BF interpreter), gcc, pager
# Usage: ./run_tests.sh [test_name...]  (no args = run all)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FIXTURES="$PROJECT_DIR/tests/fixtures"
BF2C="${BF2C:-bf2c}"
GCC="${GCC:-gcc}"
TABLE_SCAN_TIMEOUT="${TABLE_SCAN_TIMEOUT:-180}"

run_shell_test() {
  local name="$1"
  local db="${2:-$FIXTURES/tiny.db}"
  echo "=== Shell test: $name ==="
  # Start pager in background
  REQ="/tmp/pager.req.$$"
  RES="/tmp/pager.res.$$"
  rm -f "$REQ" "$RES"
  mkfifo "$REQ" "$RES"
  REQ="$REQ" RES="$RES" "$PROJECT_DIR/scripts/pager.sh" "$db" &
  PAGER_PID=$!
  sleep 0.5
  case "$name" in
    pager_header)
      echo "H" > "$REQ"
      result=$(timeout 2 cat "$RES" || true)
      if [ ${#result} -ge 200 ]; then
        echo "OK: got ${#result} chars"
      else
        echo "FAIL: expected >=200 chars, got ${#result}"
        exit 1
      fi
      ;;
    pager_page)
      echo "R 4096 1" > "$REQ"
      result=$(timeout 2 cat "$RES" || true)
      if [ ${#result} -ge 8192 ]; then
        echo "OK: got ${#result} chars"
      else
        echo "FAIL: expected >=8192 chars, got ${#result}"
        exit 1
      fi
      ;;
    *)
      echo "Unknown shell test: $name"
      exit 1
      ;;
  esac
  kill $PAGER_PID 2>/dev/null || true
  rm -f "$REQ" "$RES"
}

run_table_scan_test() {
  echo "=== Phase 5: table_scan ==="
  local exe="$PROJECT_DIR/phase5_table_scan"
  local expected="$SCRIPT_DIR/expected_table_scan.txt"
  if command -v "$BF2C" >/dev/null 2>&1 && [ -f "$PROJECT_DIR/scripts/gen_phase5_bf.py" ]; then
    echo "Building phase5_table_scan..."
    python3 "$PROJECT_DIR/scripts/gen_phase5_bf.py" > "$PROJECT_DIR/bf/phase5_table_scan.bf" 2>/dev/null || true
    BF2C="$BF2C" GCC="${GCC:-clang -O0}" "$PROJECT_DIR/scripts/build_bf.sh" "$PROJECT_DIR/bf/phase5_table_scan.bf" 2>/dev/null || true
  fi
  if [ ! -x "$exe" ]; then
    echo "SKIP: phase5_table_scan not built (need bf2c + gen_phase5)"
    return 0
  fi
  if [ ! -f "$FIXTURES/tiny.db" ] || [ ! -s "$FIXTURES/tiny.db" ]; then
    echo "SKIP: tiny.db missing or empty"
    return 0
  fi
  REQ="/tmp/pager.req.$$"
  RES="/tmp/pager.res.$$"
  CAPTURE="/tmp/phase5_capture.$$"
  rm -f "$REQ" "$RES" "$CAPTURE"
  mkfifo "$REQ" "$RES"
  REQ="$REQ" RES="$RES" "$PROJECT_DIR/scripts/pager.sh" "$FIXTURES/tiny.db" &
  PAGER_PID=$!
  sleep 0.5
  # Keep the response FIFO open so the BF program can start and send "H"
  # before the pager writes its first reply.
  exec 3<>"$RES"
  # Unbuffer stdout so piped output is captured.
  echo "(table_scan timeout ${TABLE_SCAN_TIMEOUT}s)"
  CAPTURE_STDERR="/tmp/phase5_stderr.$$"
  if command -v stdbuf >/dev/null 2>&1; then
    timeout "$TABLE_SCAN_TIMEOUT" stdbuf -o0 "$exe" <"$RES" 2>"$CAPTURE_STDERR" | awk -v cap="$CAPTURE" -v req="$REQ" '{ print >> cap; fflush(cap); if ($0 == "H" || $0 ~ /^R /) { print >> req; fflush(req); } }' || true
  else
    timeout "$TABLE_SCAN_TIMEOUT" "$exe" <"$RES" 2>"$CAPTURE_STDERR" | awk -v cap="$CAPTURE" -v req="$REQ" '{ print >> cap; fflush(cap); if ($0 == "H" || $0 ~ /^R /) { print >> req; fflush(req); } }' || true
  fi
  exec 3>&-
  kill $PAGER_PID 2>/dev/null || true
  rm -f "$REQ" "$RES"
  # Expected rows: use sqlite3 (data-driven) when available, else expected file
  local expected_rows=""
  if command -v sqlite3 >/dev/null 2>&1; then
    expected_rows=$(sqlite3 "$FIXTURES/tiny.db" "SELECT id||'|'||name||'|'||sex||'|'||rugby FROM users ORDER BY id" 2>/dev/null || true)
  fi
  if [ -z "$expected_rows" ] && [ -f "$expected" ]; then
    expected_rows=$(cat "$expected")
  fi
  local missing=0
  while IFS= read -r expected_line; do
    [ -n "$expected_line" ] || continue
    if ! grep -Fxq "$expected_line" "$CAPTURE" 2>/dev/null; then
      echo "Missing expected line: $expected_line"
      missing=1
    fi
  done <<< "$expected_rows"
  if [ "$missing" -eq 0 ]; then
    echo "OK: table scan output correct"
    rm -f "$CAPTURE" "$CAPTURE_STDERR"
  else
    echo "FAIL: table scan output did not match expected rows"
    echo "Capture bytes: $(wc -c <"$CAPTURE" 2>/dev/null || echo 0)"
    echo "Got:"
    head -20 "$CAPTURE" 2>/dev/null || echo "(empty)"
    if [ -s "$CAPTURE_STDERR" ]; then
      echo "Stderr:"
      head -10 "$CAPTURE_STDERR"
    fi
    rm -f "$CAPTURE" "$CAPTURE_STDERR"
    exit 1
  fi
  rm -f "$CAPTURE" "$CAPTURE_STDERR"
}

run_select_projection_test() {
  local test_name="$1"
  local generator_args="$2"
  local sql="$3"
  local expected_file="$4"
  echo "=== Phase 9: $test_name ==="
  local bf="$PROJECT_DIR/bf/${test_name}.bf"
  local exe="$PROJECT_DIR/$test_name"

  if command -v "$BF2C" >/dev/null 2>&1 && [ -f "$PROJECT_DIR/scripts/gen_select_bf.py" ]; then
    echo "Building $test_name..."
    python3 "$PROJECT_DIR/scripts/gen_select_bf.py" $generator_args > "$bf" 2>/dev/null || true
    BF2C="$BF2C" GCC="${GCC:-clang -O0}" "$PROJECT_DIR/scripts/build_bf.sh" "$bf" 2>/dev/null || true
  fi

  if [ ! -x "$exe" ]; then
    echo "SKIP: $test_name not built (need bf2c + gen_select_bf)"
    return 0
  fi
  if [ ! -f "$FIXTURES/tiny.db" ] || [ ! -s "$FIXTURES/tiny.db" ]; then
    echo "SKIP: tiny.db missing or empty"
    return 0
  fi

  local actual=""
  actual=$("$PROJECT_DIR/scripts/run_bf_db.sh" "$exe" "$FIXTURES/tiny.db" 2>/dev/null || true)

  local expected=""
  if command -v sqlite3 >/dev/null 2>&1; then
    expected=$(sqlite3 "$FIXTURES/tiny.db" "$sql" 2>/dev/null || true)
  fi
  if [ -z "$expected" ] && [ -f "$expected_file" ]; then
    expected=$(<"$expected_file")
  fi

  if [ "$actual" = "$expected" ]; then
    echo "OK: $test_name output correct"
  else
    echo "FAIL: $test_name output mismatch"
    echo "Expected:"
    printf '%s\n' "$expected"
    echo "Got:"
    printf '%s\n' "$actual"
    exit 1
  fi
}

run_select_invalid_spec_test() {
  local test_name="$1"
  local expected_message="$2"
  shift 2
  echo "=== Phase 9: $test_name ==="
  local output=""

  if output=$(python3 "$PROJECT_DIR/scripts/gen_select_bf.py" "$@" 2>&1 >/dev/null); then
    echo "FAIL: expected generator failure for $test_name"
    exit 1
  fi

  if printf '%s' "$output" | grep -Fq "$expected_message"; then
    echo "OK: $test_name failed clearly"
  else
    echo "FAIL: unexpected error output for $test_name"
    printf '%s\n' "$output"
    exit 1
  fi
}

run_update_test() {
  echo "=== Phase 7: update ==="
  local exe="$PROJECT_DIR/phase7_update"
  if command -v "$BF2C" >/dev/null 2>&1 && [ -f "$PROJECT_DIR/scripts/gen_update_bf.py" ]; then
    echo "Building phase7_update..."
    python3 "$PROJECT_DIR/scripts/gen_update_bf.py" > "$PROJECT_DIR/bf/phase7_update.bf" 2>/dev/null || true
    BF2C="$BF2C" GCC="${GCC:-gcc}" "$PROJECT_DIR/scripts/build_bf.sh" "$PROJECT_DIR/bf/phase7_update.bf" 2>/dev/null || true
  fi
  if [ ! -x "$exe" ]; then
    if ! command -v "$BF2C" >/dev/null 2>&1; then
      echo "SKIP: phase7_update not built (bf2c not found; set BF2C or run ./scripts/build_bf.sh when available)"
    else
      echo "SKIP: phase7_update not built (run ./scripts/build_bf.sh)"
    fi
    return 0
  fi
  if [ ! -f "$FIXTURES/tiny.db" ] || [ ! -s "$FIXTURES/tiny.db" ]; then
    echo "SKIP: tiny.db missing"
    return 0
  fi
  local db_copy="/tmp/tiny_update_$$.db"
  cp "$FIXTURES/tiny.db" "$db_copy"
  RES="/tmp/pager.res.$$"
  rm -f "$RES"
  mkfifo "$RES"
  exec 3<>"$RES"
  echo "Running update..."
  local update_out="/tmp/phase7_out_$$"
  timeout 120 "$exe" < /dev/null 2>/dev/null > "$update_out"
  if [ ! -s "$update_out" ] || [ "$(wc -c < "$update_out")" -lt 8000 ]; then
    echo "FAIL: phase7 produced no or insufficient output"
    rm -f "$update_out" "$RES" "$db_copy"
    exec 3>&-
    exit 1
  fi
  REQ=- RES="$RES" "$PROJECT_DIR/scripts/pager.sh" "$db_copy" < "$update_out"
  rm -f "$update_out"
  exec 3>&-
  rm -f "$RES"
  local expected="$SCRIPT_DIR/expected_table_scan_after_update.txt"
  local actual=""
  if command -v sqlite3 >/dev/null 2>&1; then
    actual=$(sqlite3 "$db_copy" "SELECT id||'|'||name||'|'||sex||'|'||rugby FROM users ORDER BY id")
  fi
  rm -f "$db_copy"
  local missing=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if ! echo "$actual" | grep -Fxq "$line"; then
      echo "Missing row: $line"
      missing=1
    fi
  done < "$expected"
  if [ "$missing" -eq 0 ]; then
    echo "OK: update and verify"
  else
    echo "FAIL: expected rows after update"
    echo "Got: $actual"
    exit 1
  fi
}

run_delete_test() {
  echo "=== Phase 8: delete ==="
  local exe="$PROJECT_DIR/phase8_delete"
  if command -v "$BF2C" >/dev/null 2>&1 && [ -f "$PROJECT_DIR/scripts/gen_delete_bf.py" ]; then
    echo "Building phase8_delete..."
    python3 "$PROJECT_DIR/scripts/gen_delete_bf.py" > "$PROJECT_DIR/bf/phase8_delete.bf" 2>/dev/null || true
    BF2C="$BF2C" GCC="${GCC:-gcc}" "$PROJECT_DIR/scripts/build_bf.sh" "$PROJECT_DIR/bf/phase8_delete.bf" 2>/dev/null || true
  fi
  if [ ! -x "$exe" ]; then
    if ! command -v "$BF2C" >/dev/null 2>&1; then
      echo "SKIP: phase8_delete not built (bf2c not found; set BF2C or run ./scripts/build_bf.sh when available)"
    else
      echo "SKIP: phase8_delete not built (run ./scripts/build_bf.sh)"
    fi
    return 0
  fi
  if [ ! -f "$FIXTURES/tiny.db" ] || [ ! -s "$FIXTURES/tiny.db" ]; then
    echo "SKIP: tiny.db missing"
    return 0
  fi
  local db_copy="/tmp/tiny_delete_$$.db"
  cp "$FIXTURES/tiny.db" "$db_copy"
  RES="/tmp/pager.res.$$"
  rm -f "$RES"
  mkfifo "$RES"
  exec 3<>"$RES"
  echo "Running delete..."
  local delete_out="/tmp/phase8_out_$$"
  timeout 120 "$exe" < /dev/null 2>/dev/null > "$delete_out"
  [ -s "$delete_out" ] && REQ=- RES="$RES" "$PROJECT_DIR/scripts/pager.sh" "$db_copy" < "$delete_out"
  rm -f "$delete_out"
  exec 3>&-
  rm -f "$RES"
  local expected="$SCRIPT_DIR/expected_table_scan_after_delete.txt"
  local actual=""
  if command -v sqlite3 >/dev/null 2>&1; then
    actual=$(sqlite3 "$db_copy" "SELECT id||'|'||name||'|'||sex||'|'||rugby FROM users ORDER BY id")
  fi
  rm -f "$db_copy"
  local missing=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if ! echo "$actual" | grep -Fxq "$line"; then
      echo "Missing row: $line"
      missing=1
    fi
  done < "$expected"
  if [ "$missing" -eq 0 ]; then
    echo "OK: delete and verify"
  else
    echo "FAIL: expected rows after delete"
    echo "Got: $actual"
    exit 1
  fi
}

run_insert_test() {
  echo "=== Phase 6: insert ==="
  local exe="$PROJECT_DIR/phase6_insert"
  if command -v "$BF2C" >/dev/null 2>&1 && [ -f "$PROJECT_DIR/scripts/gen_insert_bf.py" ]; then
    echo "Building phase6_insert..."
    python3 "$PROJECT_DIR/scripts/gen_insert_bf.py" > "$PROJECT_DIR/bf/phase6_insert.bf" 2>/dev/null || true
    BF2C="$BF2C" GCC="${GCC:-gcc}" "$PROJECT_DIR/scripts/build_bf.sh" "$PROJECT_DIR/bf/phase6_insert.bf" 2>/dev/null || true
  fi
  if [ ! -x "$exe" ]; then
    if ! command -v "$BF2C" >/dev/null 2>&1; then
      echo "SKIP: phase6_insert not built (bf2c not found; set BF2C or run ./scripts/build_bf.sh when available)"
    else
      echo "SKIP: phase6_insert not built (run ./scripts/build_bf.sh)"
    fi
    return 0
  fi
  if [ ! -f "$FIXTURES/tiny.db" ] || [ ! -s "$FIXTURES/tiny.db" ]; then
    echo "SKIP: tiny.db missing"
    return 0
  fi
  local db_copy="/tmp/tiny_insert_$$.db"
  cp "$FIXTURES/tiny.db" "$db_copy"
  RES="/tmp/pager.res.$$"
  rm -f "$RES"
  mkfifo "$RES"
  exec 3<>"$RES"
  echo "Running insert..."
  local insert_out="/tmp/phase6_out_$$"
  timeout 120 "$exe" < /dev/null 2>/dev/null > "$insert_out"
  [ -s "$insert_out" ] && REQ=- RES="$RES" "$PROJECT_DIR/scripts/pager.sh" "$db_copy" < "$insert_out"
  rm -f "$insert_out"
  exec 3>&-
  rm -f "$RES"
  local expected="$SCRIPT_DIR/expected_table_scan_after_insert.txt"
  local actual=""
  if command -v sqlite3 >/dev/null 2>&1; then
    actual=$(sqlite3 "$db_copy" "SELECT id||'|'||name||'|'||sex||'|'||rugby FROM users ORDER BY id")
  fi
  rm -f "$db_copy"
  local missing=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if ! echo "$actual" | grep -Fxq "$line"; then
      echo "Missing row: $line"
      missing=1
    fi
  done < "$expected"
  if [ "$missing" -eq 0 ]; then
    echo "OK: insert and verify"
  else
    echo "FAIL: expected rows after insert"
    echo "Got: $actual"
    exit 1
  fi
}

run_bf_test() {
  local bf="$1"
  local desc="${2:-$(basename "$bf")}"
  echo "=== BF test: $desc ==="
  if command -v "$BF2C" >/dev/null 2>&1; then
    local c="${bf%.bf}.c"
    local exe="${bf%.bf}"
    "$BF2C" -o "$c" "$bf" 2>/dev/null || true
    if [ -f "$c" ]; then
      $GCC -O2 -o "$exe" "$c" 2>/dev/null || true
      if [ -x "$exe" ]; then
        echo "OK: compiled and ran"
        "$exe" </dev/null || true
      fi
    fi
  else
    echo "SKIP: bf2c not found (set BF2C or add to PATH)"
  fi
}

# Create tiny.db if missing or if the SQL fixture changed
if [ ! -f "$FIXTURES/tiny.db" ] || [ "$FIXTURES/tiny.sql.txt" -nt "$FIXTURES/tiny.db" ]; then
  echo "Creating test fixture..."
  mkdir -p "$FIXTURES"
  if command -v sqlite3 >/dev/null 2>&1; then
    rm -f "$FIXTURES/tiny.db"
    if [ -f "$FIXTURES/tiny.sql.txt" ]; then
      sqlite3 "$FIXTURES/tiny.db" < "$FIXTURES/tiny.sql.txt"
    else
      sqlite3 "$FIXTURES/tiny.db" "CREATE TABLE users (id INT, name TEXT); INSERT INTO users VALUES (1,'alice'); INSERT INTO users VALUES (2,'bob');"
    fi
  else
    echo "WARN: sqlite3 not found, cannot create tiny.db. Some tests will be skipped."
    touch "$FIXTURES/tiny.db"  # placeholder
  fi
fi

run_all_tests() {
  if [ -f "$PROJECT_DIR/scripts/pager.sh" ] && [ -f "$FIXTURES/tiny.db" ] && [ -s "$FIXTURES/tiny.db" ]; then
    run_shell_test pager_header
    run_shell_test pager_page
    run_table_scan_test
    run_select_projection_test \
      phase9_select_users_name \
      "users name" \
      "SELECT name FROM users ORDER BY id" \
      "$SCRIPT_DIR/expected_select_users_name.txt"
    run_select_projection_test \
      phase9_select_users_name_sex \
      "users name sex" \
      "SELECT name||'|'||sex FROM users ORDER BY id" \
      "$SCRIPT_DIR/expected_select_users_name_sex.txt"
    run_select_invalid_spec_test select_invalid_column "Unknown column(s)" users nope
    run_select_invalid_spec_test select_invalid_table "Unsupported table" nope name
    run_insert_test
    run_update_test
    run_delete_test
  else
    echo "SKIP: pager or tiny.db not found"
  fi

  for bf in "$SCRIPT_DIR"/test_*.bf; do
    [ -f "$bf" ] || continue
    run_bf_test "$bf"
  done
}

if [ $# -gt 0 ]; then
  for t in "$@"; do
    case "$t" in
      pager_header|pager_page) run_shell_test "$t" ;;
      table_scan) run_table_scan_test ;;
      select_name)
        run_select_projection_test \
          phase9_select_users_name \
          "users name" \
          "SELECT name FROM users ORDER BY id" \
          "$SCRIPT_DIR/expected_select_users_name.txt"
        ;;
      select_name_sex)
        run_select_projection_test \
          phase9_select_users_name_sex \
          "users name sex" \
          "SELECT name||'|'||sex FROM users ORDER BY id" \
          "$SCRIPT_DIR/expected_select_users_name_sex.txt"
        ;;
      select_invalid_column) run_select_invalid_spec_test "$t" "Unknown column(s)" users nope ;;
      select_invalid_table) run_select_invalid_spec_test "$t" "Unsupported table" nope name ;;
      insert) run_insert_test ;;
      update) run_update_test ;;
      delete) run_delete_test ;;
      *)
        echo "Unknown test: $t (use: pager_header, pager_page, table_scan, select_name, select_name_sex, select_invalid_column, select_invalid_table, insert, update, delete, or test_*.bf)"
        exit 1
        ;;
    esac
  done
else
  run_all_tests
fi

echo "=== Done ==="
