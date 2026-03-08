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

phase_needs_rebuild() {
  local exe="$1"
  local bf="$2"
  local generator="$3"
  local dependency="${4:-}"

  [ ! -x "$exe" ] && return 0
  [ ! -f "$bf" ] && return 0
  [ -f "$generator" ] && [ "$generator" -nt "$bf" ] && return 0
  [ "$bf" -nt "$exe" ] && return 0
  [ -n "$dependency" ] && [ -f "$dependency" ] && [ "$dependency" -nt "$bf" ] && return 0
  return 1
}

build_generated_phase() {
  local phase_name="$1"
  local generator="$2"
  local bf="$3"
  local exe="$4"
  local compiler="$5"
  local dependency="${6:-}"
  shift 6

  if ! command -v "$BF2C" >/dev/null 2>&1 || [ ! -f "$generator" ]; then
    return 0
  fi

  if phase_needs_rebuild "$exe" "$bf" "$generator" "$dependency"; then
    echo "Building $phase_name..."
    python3 "$generator" "$@" > "$bf" 2>/dev/null || true
    BF2C="$BF2C" GCC="$compiler" "$PROJECT_DIR/scripts/build_bf.sh" "$bf" 2>/dev/null || true
  fi
}

print_stderr_excerpt() {
  local stderr_file="$1"
  if [ -s "$stderr_file" ]; then
    echo "Stderr:"
    sed -n '1,10p' "$stderr_file"
  fi
}

run_write_program_capture() {
  local test_name="$1"
  local exe="$2"
  local output_file="$3"
  local stderr_file="$4"
  local timeout_secs="${5:-120}"
  local run_rc=0

  set +e
  timeout "$timeout_secs" "$exe" < /dev/null > "$output_file" 2> "$stderr_file"
  run_rc=$?
  set -e

  if [ "$run_rc" -eq 124 ]; then
    echo "FAIL: $test_name timed out after ${timeout_secs}s"
    print_stderr_excerpt "$stderr_file"
    return 1
  fi

  if [ "$run_rc" -ne 0 ]; then
    echo "FAIL: $test_name exited with status $run_rc"
    print_stderr_excerpt "$stderr_file"
    return 1
  fi

  return 0
}

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
  echo "=== sqlite_table_scan ==="
  local exe="$PROJECT_DIR/sqlite_table_scan"
  local expected="$SCRIPT_DIR/expected_table_scan.txt"
  build_generated_phase \
    sqlite_table_scan \
    "$PROJECT_DIR/scripts/gen_sqlite_table_scan_bf.py" \
    "$PROJECT_DIR/bf/sqlite_table_scan.bf" \
    "$exe" \
    "${GCC:-clang -O0}" \
    "$FIXTURES/tiny.db"
  if [ ! -x "$exe" ]; then
    echo "SKIP: sqlite_table_scan not built (need bf2c + table-scan generator)"
    return 0
  fi
  if [ ! -f "$FIXTURES/tiny.db" ] || [ ! -s "$FIXTURES/tiny.db" ]; then
    echo "SKIP: tiny.db missing or empty"
    return 0
  fi
  REQ="/tmp/pager.req.$$"
  RES="/tmp/pager.res.$$"
  CAPTURE="/tmp/sqlite_table_scan_capture.$$"
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
  CAPTURE_STDERR="/tmp/sqlite_table_scan_stderr.$$"
  local run_rc=0
  local awk_rc=0
  local pipe_status=()
  set +e
  if command -v stdbuf >/dev/null 2>&1; then
    timeout "$TABLE_SCAN_TIMEOUT" stdbuf -o0 "$exe" <"$RES" 2>"$CAPTURE_STDERR" | awk -v cap="$CAPTURE" -v req="$REQ" '{ print >> cap; fflush(cap); if ($0 == "H" || $0 ~ /^R /) { print >> req; fflush(req); } }'
    pipe_status=("${PIPESTATUS[@]}")
    run_rc=${pipe_status[0]:-0}
    awk_rc=${pipe_status[1]:-0}
  else
    timeout "$TABLE_SCAN_TIMEOUT" "$exe" <"$RES" 2>"$CAPTURE_STDERR" | awk -v cap="$CAPTURE" -v req="$REQ" '{ print >> cap; fflush(cap); if ($0 == "H" || $0 ~ /^R /) { print >> req; fflush(req); } }'
    pipe_status=("${PIPESTATUS[@]}")
    run_rc=${pipe_status[0]:-0}
    awk_rc=${pipe_status[1]:-0}
  fi
  set -e
  exec 3>&-
  kill $PAGER_PID 2>/dev/null || true
  rm -f "$REQ" "$RES"
  if [ "$run_rc" -eq 124 ]; then
    echo "FAIL: sqlite_table_scan timed out after ${TABLE_SCAN_TIMEOUT}s"
    print_stderr_excerpt "$CAPTURE_STDERR"
    rm -f "$CAPTURE" "$CAPTURE_STDERR"
    exit 1
  fi
  if [ "$run_rc" -ne 0 ]; then
    echo "FAIL: sqlite_table_scan exited with status $run_rc"
    print_stderr_excerpt "$CAPTURE_STDERR"
    rm -f "$CAPTURE" "$CAPTURE_STDERR"
    exit 1
  fi
  if [ "$awk_rc" -ne 0 ]; then
    echo "FAIL: sqlite_table_scan capture pipeline exited with status $awk_rc"
    rm -f "$CAPTURE" "$CAPTURE_STDERR"
    exit 1
  fi
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
  echo "=== $test_name ==="
  local bf="$PROJECT_DIR/bf/${test_name}.bf"
  local exe="$PROJECT_DIR/$test_name"

  # shellcheck disable=SC2086
  build_generated_phase \
    "$test_name" \
    "$PROJECT_DIR/scripts/gen_select_bf.py" \
    "$bf" \
    "$exe" \
    "${GCC:-clang -O0}" \
    "$FIXTURES/tiny.db" \
    $generator_args

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
  echo "=== $test_name ==="
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
  echo "=== sqlite_update ==="
  local exe="$PROJECT_DIR/sqlite_update"
  build_generated_phase \
    sqlite_update \
    "$PROJECT_DIR/scripts/gen_update_bf.py" \
    "$PROJECT_DIR/bf/sqlite_update.bf" \
    "$exe" \
    "${GCC:-gcc}" \
    "$FIXTURES/tiny.db"
  if [ ! -x "$exe" ]; then
    if ! command -v "$BF2C" >/dev/null 2>&1; then
      echo "SKIP: sqlite_update not built (bf2c not found; set BF2C or run ./scripts/build_bf.sh when available)"
    else
      echo "SKIP: sqlite_update not built (run ./scripts/build_bf.sh)"
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
  local update_out="/tmp/sqlite_update_out_$$"
  local update_err="/tmp/sqlite_update_err_$$"
  if ! run_write_program_capture "sqlite_update" "$exe" "$update_out" "$update_err" 120; then
    rm -f "$update_out" "$update_err" "$RES" "$db_copy"
    exec 3>&-
    exit 1
  fi
  if [ ! -s "$update_out" ] || [ "$(wc -c < "$update_out")" -lt 8000 ]; then
    echo "FAIL: sqlite_update produced no or insufficient output"
    print_stderr_excerpt "$update_err"
    rm -f "$update_out" "$update_err" "$RES" "$db_copy"
    exec 3>&-
    exit 1
  fi
  REQ=- RES="$RES" "$PROJECT_DIR/scripts/pager.sh" "$db_copy" < "$update_out"
  rm -f "$update_out" "$update_err"
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
  echo "=== sqlite_delete ==="
  local exe="$PROJECT_DIR/sqlite_delete"
  build_generated_phase \
    sqlite_delete \
    "$PROJECT_DIR/scripts/gen_delete_bf.py" \
    "$PROJECT_DIR/bf/sqlite_delete.bf" \
    "$exe" \
    "${GCC:-gcc}" \
    "$FIXTURES/tiny.db"
  if [ ! -x "$exe" ]; then
    if ! command -v "$BF2C" >/dev/null 2>&1; then
      echo "SKIP: sqlite_delete not built (bf2c not found; set BF2C or run ./scripts/build_bf.sh when available)"
    else
      echo "SKIP: sqlite_delete not built (run ./scripts/build_bf.sh)"
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
  local delete_out="/tmp/sqlite_delete_out_$$"
  local delete_err="/tmp/sqlite_delete_err_$$"
  if ! run_write_program_capture "sqlite_delete" "$exe" "$delete_out" "$delete_err" 120; then
    rm -f "$delete_out" "$delete_err" "$RES" "$db_copy"
    exec 3>&-
    exit 1
  fi
  if [ ! -s "$delete_out" ] || [ "$(wc -c < "$delete_out")" -lt 8000 ]; then
    echo "FAIL: sqlite_delete produced no or insufficient output"
    print_stderr_excerpt "$delete_err"
    rm -f "$delete_out" "$delete_err" "$RES" "$db_copy"
    exec 3>&-
    exit 1
  fi
  REQ=- RES="$RES" "$PROJECT_DIR/scripts/pager.sh" "$db_copy" < "$delete_out"
  rm -f "$delete_out" "$delete_err"
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
  echo "=== sqlite_insert ==="
  local exe="$PROJECT_DIR/sqlite_insert"
  build_generated_phase \
    sqlite_insert \
    "$PROJECT_DIR/scripts/gen_insert_bf.py" \
    "$PROJECT_DIR/bf/sqlite_insert.bf" \
    "$exe" \
    "${GCC:-gcc}" \
    "$FIXTURES/tiny.db"
  if [ ! -x "$exe" ]; then
    if ! command -v "$BF2C" >/dev/null 2>&1; then
      echo "SKIP: sqlite_insert not built (bf2c not found; set BF2C or run ./scripts/build_bf.sh when available)"
    else
      echo "SKIP: sqlite_insert not built (run ./scripts/build_bf.sh)"
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
  local insert_out="/tmp/sqlite_insert_out_$$"
  local insert_err="/tmp/sqlite_insert_err_$$"
  if ! run_write_program_capture "sqlite_insert" "$exe" "$insert_out" "$insert_err" 120; then
    rm -f "$insert_out" "$insert_err" "$RES" "$db_copy"
    exec 3>&-
    exit 1
  fi
  if [ ! -s "$insert_out" ] || [ "$(wc -c < "$insert_out")" -lt 8000 ]; then
    echo "FAIL: sqlite_insert produced no or insufficient output"
    print_stderr_excerpt "$insert_err"
    rm -f "$insert_out" "$insert_err" "$RES" "$db_copy"
    exec 3>&-
    exit 1
  fi
  REQ=- RES="$RES" "$PROJECT_DIR/scripts/pager.sh" "$db_copy" < "$insert_out"
  rm -f "$insert_out" "$insert_err"
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
      sqlite_select_users_name \
      "users name" \
      "SELECT name FROM users ORDER BY id" \
      "$SCRIPT_DIR/expected_select_users_name.txt"
    run_select_projection_test \
      sqlite_select_users_name_sex \
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
          sqlite_select_users_name \
          "users name" \
          "SELECT name FROM users ORDER BY id" \
          "$SCRIPT_DIR/expected_select_users_name.txt"
        ;;
      select_name_sex)
        run_select_projection_test \
          sqlite_select_users_name_sex \
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
