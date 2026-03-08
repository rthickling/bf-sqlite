# BF-SQLite

**SQLite file-format access in BrainFuck.** The shell side only moves bytes. The BrainFuck side does the interesting work: header parsing, page reads, schema walking, table scans, and small controlled writes.

## Why I Built This

This project is an intentionally absurd demonstration.

The point is not that BrainFuck is a sensible language for database work. The point is that a piece of software which would normally feel intractable can now be assembled surprisingly quickly with AI assistance.

In roughly a day of part-time work, this repo went from idea to a working demo that can:

- read the SQLite header
- walk schema pages
- scan a table
- perform small controlled writes

## What works now

- Header read and validation
- Page reads
- Schema walk
- Table scan
- `INSERT`, `UPDATE`, and `DELETE` on the tiny demo database

## Quick start

Add `bin/` to your shell `PATH` for this checkout:

```bash
export PATH="$PWD/bin:$PATH"
```

Build the toolchain from scratch:

```bash
build-image
```

Run the smallest demo:

```bash
run-bf-db examples/01_hello_header.bf tests/fixtures/tiny.db
```

Scan the demo table:

```bash
run-bf-db ./phase5_table_scan tests/fixtures/tiny.db
```

Run the proof suite:

```bash
run-tests
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

With `bin/` on your `PATH`, the top-level commands feel like a local toolchain:

- `build-image`
- `build-bf`
- `run-bf-db`
- `run-tests`
- `shell`

For the non-Docker/manual toolchain path, see the appendix in `docs/DETAILED_BUILD_PLAN.md`.

## Scope

This is a BrainFuck-driven SQLite file-format demo, not a full SQLite replacement or SQL engine.
