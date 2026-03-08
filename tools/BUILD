# BF-SQLite Toolchain

The Docker image builds the whole toolchain from scratch:

- `bf2c`
- `gcc` / `clang`
- `python3`
- `sqlite3`

Build it once:

```bash
export PATH="$PWD/bin:$PATH"
build-image
```

Then use the wrapper scripts from the host:

```bash
run-bf-db examples/01_hello_header.bf tests/fixtures/tiny.db
```

Useful commands:

```bash
run-bf-db ./phase5_table_scan tests/fixtures/tiny.db

run-tests
shell
```

`scripts/run_bf_db.sh` will build missing phase binaries and create the demo database when needed.
