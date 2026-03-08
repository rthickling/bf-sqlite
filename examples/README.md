# Examples

The public demo surface is intentionally small.

## Runnable demos

| Demo | Command | Result |
|------|---------|--------|
| Header read | `./bin/run-bf-db examples/01_hello_header.bf tests/fixtures/tiny.db` | Prints `OK` |
| Table scan | `./bin/run-bf-db ./phase5_table_scan tests/fixtures/tiny.db` | Prints the four `users` rows |
| Write proofs | `./bin/run-tests insert update delete` | Verifies `INSERT`, `UPDATE`, and `DELETE` |

`scripts/run_bf_db.sh` will build missing phase binaries and create `tests/fixtures/tiny.db` when the necessary tools are available.

## Reference material

Protocol sketches and partial examples live in `examples/reference/`.

## Notes

- Comments use `#`; BrainFuck ignores them.
- The heavier phase implementations live in `bf/`.
