# BF-SQLite Toolchain

The Docker image builds the whole toolchain from scratch:

- `bf2c`
- `gcc` / `clang`
- `python3`
- `sqlite3`

Build it once:

```bash
docker build -f tools/Dockerfile -t bf-sqlite .
```

Then use the mounted repo as your working tree:

```bash
docker run --rm -v "$(pwd)":/work bf-sqlite \
  ./scripts/run_bf_db.sh examples/01_hello_header.bf tests/fixtures/tiny.db
```

Useful commands:

```bash
docker run --rm -v "$(pwd)":/work bf-sqlite \
  ./scripts/run_bf_db.sh ./phase5_table_scan tests/fixtures/tiny.db

docker run --rm -v "$(pwd)":/work bf-sqlite ./tests/run_tests.sh
```

`scripts/run_bf_db.sh` will build missing phase binaries and create the demo database when needed.
