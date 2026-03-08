# BF-SQLite Toolchain

The Docker image builds the whole toolchain from scratch:

- `bf2c`
- `gcc` / `clang`
- `python3`
- `sqlite3`

Build it once:

```bash
./scripts/docker_build_image.sh
```

Then use the wrapper scripts from the host:

```bash
./scripts/docker_run_bf_db.sh examples/01_hello_header.bf tests/fixtures/tiny.db
```

Useful commands:

```bash
./scripts/docker_run_bf_db.sh ./phase5_table_scan tests/fixtures/tiny.db

./scripts/docker_run_tests.sh
./scripts/docker_shell.sh
```

`scripts/run_bf_db.sh` will build missing phase binaries and create the demo database when needed.
