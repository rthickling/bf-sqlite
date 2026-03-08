# BF-SQLite

**SQLite file-format access in BrainFuck** : an experiment in interacting with SQLite databases from Brainfuck using only standard Linux primitives.

The shell side only moves bytes. The BrainFuck side does the interesting work: header parsing, page reads, schema walking, table scans, limited column projection, and small controlled writes.

## Why I Built This

This project is an intentionally absurd demonstration.

The point is not that BrainFuck is a sensible language for database work. The point is that a piece of software which would normally feel intractable can now be assembled surprisingly quickly with AI assistance.

In roughly a day of part-time work, this repo went from idea to a working demo that can:

- read the SQLite header
- walk schema pages
- scan a table
- project selected columns from the demo table
- perform small controlled writes

## What works now

- Header read and validation
- Page reads
- Schema walk
- Table scan
- Limited `SELECT`-style projection on the demo `users` table:
  `SELECT name FROM users;` and `SELECT name, sex FROM users;`
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
run-bf-db ./sqlite_table_scan tests/fixtures/tiny.db
```

Project selected columns from the demo table:

```bash
run-bf-db ./sqlite_select_users_name tests/fixtures/tiny.db
run-bf-db ./sqlite_select_users_name_sex tests/fixtures/tiny.db
```

These are the current `SELECT` equivalents:

```sql
SELECT name FROM users;
SELECT name, sex FROM users;
```

Current scope is intentionally small: single-table projection on the demo
`users` table only, with no `WHERE`, `ORDER BY`, joins, or expressions.

Run the proof suite:

```bash
run-tests
```

`run-bf-db` will build missing demo binaries automatically and create `tests/fixtures/tiny.db` when `sqlite3` is available.
`run-tests` will also reuse existing generated demo executables and only rebuild stale ones.

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

- `scripts/run_bf_db.sh` runs any `.bf` file or built demo executable against a database
- `examples/01_hello_header.bf` is the minimal runnable demo
- `sqlite_select_users_name` and `sqlite_select_users_name_sex` are the built
  `SELECT` equivalents in the demo
- `tests/run_tests.sh` is the proof runner behind `run-tests`
- `docs/USAGE.md` explains the pager protocol and BF integration model
- `tests/TESTS.md` summarizes what is verified

## Repo guide

- `bf/` contains the named SQLite demo programs and BF helper libraries
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
