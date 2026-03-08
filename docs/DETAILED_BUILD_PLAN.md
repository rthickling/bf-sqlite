# BrainFuck SQLite Interface: Detailed Build Plan

## Overview

This document provides a comprehensive, implementable plan for building a BrainFuck-based SQLite file reader/writer using only pipes, FIFOs, and core Linux utilities. It combines the architecture and build notes into a single implementation roadmap.

---

## Components

| Component | Implemented in | Purpose |
|-----------|----------------|---------|
| **Shell pager harness** | bash | Manages FIFOs, runs dd/od/tr, handles H and R requests |
| **BrainFuck pager client** | BrainFuck | Sends H/R commands to pager, reads hex responses |
| **Hex decoder** | BrainFuck | Converts ASCII hex pairs → raw bytes |
| **SQLite header parser** | BrainFuck | Parses 100-byte header, validates magic, extracts fields |
| **B-tree page walker** | BrainFuck | Traverses pages, reads cell pointers, decodes cells |

---

## Phase Plan (Staged Implementation)

### Phase 1: Foundation (Shell Pager + BF Pager Client + Hex Decoder)

**Deliverables**

1. **Shell pager harness** (`scripts/pager.sh`)
   - Supports `H` (return first 100 bytes as hex)
   - Supports `R <page_size> <page_no>`
   - Uses `dd`, `od -An -tx1 -v`, `tr -d ' \n'`
   - FIFOs for request/response

2. **BrainFuck pager client**
   - Emit `H\n` to stdout
   - Read response line (until newline)
   - Store hex chars in tape buffer

3. **Hex decoder** (`bf/lib_hex_decode.bf`)
   - Input: two consecutive ASCII hex chars
   - Output: one byte (0x00–0xFF)
   - Logic: high = char→nibble, low = char→nibble, byte = (high<<4)|low
   - Must handle 0-9 and a-f (lowercase)

**Success criteria**
- Shell: `echo "H" | pager.sh db` returns 200 hex chars + newline
- BF: requests H, reads 200 hex chars, decodes to 100 bytes

**Status**: Phase 1–3 done. Phase 4: `scripts/gen_phase4_bf.py` parses the first `sqlite_schema` cell, extracts `rootpage`, decodes the record at offset 4034, and outputs the result. Build with `./scripts/build_bf.sh`, run with `INSPECTOR=./phase4_schema_walk ./scripts/run_inspector.sh db`.

---

### Phase 2: SQLite Header Parser

**Deliverables**

1. **Header validator**
   - Compare bytes 0–15 to `SQLite format 3\0`
   - Set error flag on mismatch

2. **Field extraction** (big-endian, BrainFuck)
   - Offset 16–17: page size (2 bytes)
   - Offset 18: file format write version
   - Offset 19: file format read version
   - Offset 24–27: change counter (4 bytes)
   - Offset 28–31: page count (4 bytes)
   - Offset 32–35: freelist head (4 bytes)
   - Offset 36–39: freelist count (4 bytes)

3. **Big-endian decoder** (`bf/lib_big_endian.bf`)
   - 2-byte: `(b0 << 8) | b1`
   - 4-byte: `(b0<<24)|(b1<<16)|(b2<<8)|b3`
   - Keep byte-oriented until needed

**Success criteria**
- BF program validates magic, prints/emits page size and page count
- Rejects non-SQLite files

---

### Phase 3: Page 1 B-Tree Header Parser

**Deliverables**

1. **Page request**
   - BF emits `R <page_size> 1` (page_size from header)
   - Need decimal→ASCII for page_size (e.g. 4096 → "4096")

2. **Page 1 layout**
   - First 100 bytes = file header (already parsed)
   - B-tree header starts at **byte 100**
   - Parse:
     - 1 byte: page type (2, 5, 10, 13)
     - 2 bytes: first freeblock offset
     - 2 bytes: cell count
     - 2 bytes: cell content area start
     - 1 byte: fragmented free bytes count
     - 4 bytes: right child (interior only)

3. **Cell pointer array**
   - Starts immediately after 8-byte B-tree header (interior) or 12-byte (leaf)
   - For page 1: cell content area typically begins at end of page
   - Cell pointers: 2-byte big-endian offsets into page

**Success criteria**
- BF parses page 1 B-tree header
- Reads cell count and cell pointer array
- Dumps or inspects cell offsets

---

### Phase 4: Schema Walker (sqlite_schema)

**Deliverables**

1. **Cell parsing for leaf table**
   - Payload size (varint)
   - Rowid (varint)
   - Payload (header + body)
   - Header: varints for serial types
   - Body: values per serial type

2. **Varint decoder** (`bf/lib_varint.bf`)
   - SQLite varint: up to 9 bytes
   - High bit = continue, low 7 = data
   - Accumulate into value

3. **Schema record parsing**
   - sqlite_schema columns: type, name, tbl_name, rootpage, sql
   - Extract rootpage for user tables
   - Extract name for table lookup

**Success criteria**
- BF walks sqlite_schema cells
- Extracts at least one user table root page
- Can identify table by name

---

### Phase 5: Table Scan (User Data)

**Deliverables**

1. **Table B-tree traversal**
   - Request page N via `R <page_size> N`
   - If interior (type 5): follow leftmost or binary search
   - If leaf (type 13): decode leaf cells

2. **Leaf table cell decoding**
   - Parse payload header (varints for serial types)
   - Decode body: NULL, int, float, blob, text
   - For Phase 5: support small integers and short text

3. **Output**
   - Emit row data as ASCII (e.g. comma-separated)
   - Or structured for downstream use

**Success criteria**
- BF reads rows from a simple user table
- Handles fixed small schema (e.g. id INT, name TEXT)
- Output is human-readable

**Status**: Phase 5 done. `scripts/gen_phase5_bf.py` does Phase 1–4, then R 4096 2, reads page 2, decodes cells, outputs `1|alice\n2|bob\n` for tiny.db users table.

---

### Phase 6: Controlled Writes (Future)

**Deliverables**
- Shell pager: `W <page_size> <page_no> <hex_data>`
- BF: encode modified page as hex, send W command
- Initially: overwrite single page, no freelist/journal
- Strict constraints: small DBs, no concurrent access

**Success criteria**
- Modify one leaf page, verify with sqlite3
- No immediate corruption

---

## BrainFuck Module Layout

```
bf/
  lib_ascii_io.bf      # Read char, write char, read line
  lib_hex_decode.bf    # Hex pair → byte
  lib_big_endian.bf    # 2/4-byte BE decode
  lib_varint.bf        # SQLite varint decode
  lib_decimal_out.bf   # Byte → ASCII decimal (for R cmd)
  phase1_header_inspector.bf
  phase2_page1_parser.bf
  phase3_cellptrs.bf
  phase4_schema_walk.bf
  phase5_table_scan.bf
  bf_sqlite.bf         # Integrated engine (later)
```

---

## Tape Layout (Suggested)

```
0-15    Registers (current char, temp, nibbles, counters, flags)
16-31   Command construction ("H\n", "R 4096 1")
32-63   Decimal output scratch
64-511  Raw hex input buffer (max 2*page_size for 4096)
512-611 Decoded header (100 bytes)
612+    Decoded page buffer (grows with page size)
        Cell pointer array, varint scratch, etc.
```

---

## Test Strategy

### 1. Shell Tests (scripts only)

| Test | Command | Expect |
|------|---------|--------|
| pager_header | `echo "H"` into pager | 200 hex chars, newline |
| pager_page | `echo "R 4096 1"` | 8192 hex chars, newline |
| pager_err | `echo "X"` | `ERR` |

### 2. BrainFuck Unit-Style Tests

Create minimal `.bf` programs that exercise one capability:

| Test | File | What it tests |
|------|------|----------------|
| `test_hex_decode.bf` | Read fixed hex string, decode, emit first byte | Hex decoder |
| `test_big_endian.bf` | Decode 0x10 0x00 → 4096 | Big-endian |
| `test_varint.bf` | Decode 0x81 0x00 | Varint |
| `test_magic.bf` | Compare 16 bytes to "SQLite format 3\0" | Magic validation |
| `test_header_integration.bf` | Full H request, decode, validate, extract page_size | Phase 1+2 |
| `test_page1.bf` | H, R, parse B-tree header | Phase 3 |
| `test_schema.bf` | Walk sqlite_schema, emit first rootpage | Phase 4 |
| `test_table_scan.bf` | Read rows from known table | Phase 5 |

### 3. Fixtures

```
tests/fixtures/
  tiny.db           # Pre-built SQLite DB (one table, 2–3 rows)
  tiny.sql.txt      # SQL used to create it
  expected_header.txt   # page_size, page_count, etc.
  page1_hex.txt     # Optional: known page 1 hex for diff
```

### 4. Test Runner

`tests/run_tests.sh`:

- Start pager in background with `tiny.db`
- For each BF test:
  - Compile `.bf` → `.c` (bf2c) → executable (gcc)
  - Run with stdin from pager response FIFO, stdout captured
  - Compare output to expected (or check exit/format)
- Cleanup

---

## Example Usage

### Create Test Database (one-time, requires sqlite3 for fixture creation)

```bash
# Optional: if sqlite3 available for fixture creation only
sqlite3 tests/fixtures/tiny.db "CREATE TABLE users (id INT, name TEXT); INSERT INTO users VALUES (1,'alice'); INSERT INTO users VALUES (2,'bob');"
```

### Run Header Inspector

```bash
./scripts/pager.sh tests/fixtures/tiny.db &
PAGER_PID=$!
sleep 1
./bf_inspector < pager.req > pager.res  # or use run script
kill $PAGER_PID
```

### Run Integrated Reader (Phase 5)

```bash
./scripts/run_reader.sh tests/fixtures/tiny.db users
# Expected: id,name rows printed
```

### High-Level Flow

```
User runs: ./run_reader.sh my.db my_table

1. run_reader.sh starts pager.sh with my.db
2. run_reader.sh compiles bf_sqlite.bf (or phase5_table_scan.bf) via bf2c + gcc
3. BF executable connects to FIFOs
4. BF: sends H, gets header, parses page size
5. BF: sends R <page_size> 1, gets page 1
6. BF: parses sqlite_schema, finds my_table rootpage
7. BF: requests that page, traverses, decodes rows
8. BF: prints rows to stdout
9. run_reader.sh collects output and exits
```

---

## GitHub Distribution Layout

```
bf-sqlite/
  .cursor/rules/
    bf-sqlite.mdc
  .gitignore
  LICENSE                 # MIT or similar
  README.md
  docs/
    architecture.md       # archived architecture note
    build_plan.md         # archived build-plan note
    DETAILED_BUILD_PLAN.md
    sqlite_subset.md      # SQLite format notes
  scripts/
    pager.sh
    run_inspector.sh
    run_reader.sh
    make_test_db.sh       # Optional, if sqlite3 allowed for fixtures
  bf/
    lib_*.bf
    phase*.bf
    bf_sqlite.bf
  tests/
    fixtures/
      tiny.db
      tiny.sql.txt
      expected_header.txt
    test_*.bf
    run_tests.sh
  examples/
    hello_schema.bf       # Minimal: print schema table names
    dump_table.bf         # Dump one table's rows
```

---

## Build & Run Instructions (README)

1. **Prerequisites**
   - Linux (or compatible Unix)
   - bash, dd, od, tr, printf, mkfifo
   - bf2c (brainfuck-compiler-c) + gcc for compiling BF
   - Or: BrainFuck interpreter (beef, etc.) to run .bf directly

2. **Build**
   ```bash
   # If using bf2c in Docker:
   docker run -v $(pwd):/work your-bf2c-image bash -c "cd /work && ./scripts/build_bf.sh"
   ```

3. **Run**
   ```bash
   ./scripts/run_reader.sh path/to/db.sqlite table_name
   ```

---

## What Not to Claim

- "SQLite in BrainFuck"
- "Full SQLite engine"
- "SQLite-compatible"

**Accurate**:
- "SQLite file-format reader/writer core in BrainFuck"
- "BrainFuck SQLite page parser via shell pager"

---

## Appendix: Without Docker

If you want to use the project with a local toolchain instead of the Docker wrappers, the rough workflow is:

1. Install:
   - `bf2c`
   - `python3`
   - a C compiler (`gcc` or `clang`)
   - `sqlite3` if you want the fixture DB created automatically

2. Build the phase programs:
   ```bash
   ./scripts/build_bf.sh
   ```

3. Run a BF program against the demo database:
   ```bash
   ./scripts/run_bf_db.sh examples/01_hello_header.bf tests/fixtures/tiny.db
   ./scripts/run_bf_db.sh ./phase5_table_scan tests/fixtures/tiny.db
   ```

4. Run the tests:
   ```bash
   ./tests/run_tests.sh
   ```

Notes:

- `run_bf_db.sh` uses `python3` locally to route pager commands and responses.
- `run_bf_db.sh` will create `tests/fixtures/tiny.db` from `tests/fixtures/tiny.sql.txt` when `sqlite3` is available.
- For phases 4–8, `GCC="clang -O0"` is often more reliable than `gcc`.
- If you want the cleaner Docker-first commands, add `bin/` to your `PATH` from the project root and use `build-image`, `run-bf-db`, and `run-tests` instead.
