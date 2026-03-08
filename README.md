# BF-SQLite

**SQLite file-format access in BrainFuck.** The shell side only moves bytes. The BrainFuck side does the interesting work: header parsing, page reads, schema walking, table scans, and small controlled writes.

## What works now

- Header read and validation
- Page reads
- Schema walk
- Table scan
- `INSERT`, `UPDATE`, and `DELETE` on the tiny demo database

## Quick start

Build the toolchain from scratch:

```bash
./scripts/docker_build_image.sh
```

Run the smallest demo:

```bash
./scripts/docker_run_bf_db.sh examples/01_hello_header.bf tests/fixtures/tiny.db
```

Scan the demo table:

```bash
./scripts/docker_run_bf_db.sh ./phase5_table_scan tests/fixtures/tiny.db
```

Run the proof suite:

```bash
./scripts/docker_run_tests.sh
```

`run_bf_db.sh` will build missing phase binaries automatically and create `tests/fixtures/tiny.db` when `sqlite3` is available.

## How it works

```
SQLite .db file
       ↑
       │ dd / raw page bytes
       │
Shell pager
       ↑
       │ ASCII request/response
       │
BrainFuck program
```

The protocol is intentionally small:

- `H` reads the 100-byte SQLite header as hex
- `R <page_size> <page_no>` reads a page as hex
- `W <page_size> <page_no>` writes a page back as hex

## Main entry points

- `scripts/run_bf_db.sh` runs any `.bf` file or built phase executable against a database
- `examples/01_hello_header.bf` is the minimal runnable demo
- `docs/USAGE.md` explains the pager protocol and BF integration model
- `tests/TESTS.md` summarizes what is verified

## Repo guide

- `bf/` contains the phase programs and BF helper libraries
- `examples/` contains the curated demo plus reference sketches
- `scripts/` contains the pager, build, and run helpers
- `tools/` contains the Dockerized toolchain
- `docs/archive/` contains older planning and maintenance notes

The Docker wrappers are designed to feel like a local toolchain:

- `./scripts/docker_build_image.sh`
- `./scripts/docker_build_bf.sh`
- `./scripts/docker_run_bf_db.sh`
- `./scripts/docker_run_tests.sh`
- `./scripts/docker_shell.sh`

For the non-Docker/manual toolchain path, see the appendix in `docs/DETAILED_BUILD_PLAN.md`.

## Scope

This is a BrainFuck-driven SQLite file-format demo, not a full SQLite replacement or SQL engine.
