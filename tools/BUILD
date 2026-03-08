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
run-bf-db ./sqlite_table_scan tests/fixtures/tiny.db
run-bf-db ./sqlite_select_users_name_sex tests/fixtures/tiny.db

run-tests
shell
```

`run-bf-db` will build missing demo binaries and create the demo database when needed.
`run-tests` reuses existing generated demo executables and only rebuilds stale ones.
