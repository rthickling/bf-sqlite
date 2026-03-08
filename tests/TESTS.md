# BrainFuck Test Suite

This test suite is meant to prove the interesting claims quickly.

## What is proven

| Capability | Test |
|------------|------|
| Pager returns SQLite header hex | `pager_header` |
| Pager returns full page hex | `pager_page` |
| BrainFuck can scan a real table | `table_scan` |
| BrainFuck can project selected columns | `select_name`, `select_name_sex` |
| BrainFuck can write a row | `insert` |
| BrainFuck can update a row | `update` |
| BrainFuck can delete a row | `delete` |
| BF helpers still behave | `test_echo.bf`, `test_hex_decode.bf`, `test_hex_one.bf`, `test_magic.bf` |

## Run everything

Add `bin/` to your `PATH` first:

```bash
export PATH="$PWD/bin:$PATH"
```

```bash
run-tests
```

Docker:

```bash
run-tests
```

Selected checks:

```bash
run-tests table_scan
run-tests select_name
run-tests select_name_sex
run-tests insert
run-tests update
run-tests delete
```

## Expectations

- `table_scan` should match:
  - `1|alice|F|France`
  - `2|bob|M|England`
  - `3|bert|M|Australia`
  - `4|jude|M|USA`
- `select_name` should match:
  - `alice`
  - `bob`
  - `bert`
  - `jude`
- `select_name_sex` should match:
  - `alice|F`
  - `bob|M`
  - `bert|M`
  - `jude|M`
- `insert` should add `5|chip|M|Wales`
- `update` should change `jude` to `judy`
- `delete` should remove row `4`

## Notes

- `run-tests` is the Docker-first path once `bin/` is on your `PATH`. The local/manual runner is `./tests/run_tests.sh`.
- `tests/run_tests.sh` will create `tests/fixtures/tiny.db` when `sqlite3` is available.
- Phases 4–8 compile more reliably with `GCC="clang -O0"`.
- `table_scan` is the slowest test; generated phase 5 BF is large.

## Fixtures

- `tests/fixtures/tiny.sql.txt` defines the demo database
- `tests/expected_table_scan.txt` is the expected scan output
- `tests/expected_table_scan_after_insert.txt` is the expected state after insert
- `tests/expected_table_scan_after_update.txt` is the expected state after update
- `tests/expected_table_scan_after_delete.txt` is the expected state after delete
