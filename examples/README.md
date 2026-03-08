# Examples

The public demo surface is intentionally small.

## Runnable demos

Add `bin/` to your `PATH` first:

```bash
export PATH="$PWD/bin:$PATH"
```

| Demo | Command | Result |
|------|---------|--------|
| Header read | `run-bf-db examples/01_hello_header.bf tests/fixtures/tiny.db` | Prints `OK` |
| Table scan | `run-bf-db ./sqlite_table_scan tests/fixtures/tiny.db` | Prints the four `users` rows |
| Limited SELECT | `run-bf-db ./sqlite_select_users_name_sex tests/fixtures/tiny.db` | Prints `name|sex` for the demo `users` rows |
| Narrow CREATE TABLE | `run-bf-db ./sqlite_create_log_table tests/fixtures/tiny.db` | Adds an empty `log(ts INT, value TEXT)` table to a writable DB |
| Write proofs | `run-tests insert update delete` | Verifies `INSERT`, `UPDATE`, and `DELETE` on a writable copy of the demo DB |

`run-bf-db` will build missing demo binaries and create `tests/fixtures/tiny.db` when the necessary tools are available.
`run-tests` reuses existing generated demo executables and only rebuilds stale ones.

## Reference material

Protocol sketches and partial examples live in `examples/reference/`.

## Notes

- Comments use `#`; BrainFuck ignores them.
- The heavier generated implementations live in `bf/`.
