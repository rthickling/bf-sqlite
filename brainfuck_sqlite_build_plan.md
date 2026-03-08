# Cursor Build Plan: Brainfuck SQLite File Reader/Writer via `dd` and Pipes

## Purpose

This document is designed to be given directly to Cursor so it can continue the project with minimal ambiguity.

The project goal is:

> Build a system where Brainfuck performs as much of the SQLite database logic as possible, while shell scripts and core Linux tools only transport raw page bytes.

Constraints:

- no new compiled C code
- no `sqlite3` CLI
- no non-core packages required for the runtime path
- use Brainfuck, shell, FIFOs, `dd`, `od`, `tr`, `printf`, `mkfifo`, `stat`
- start read-only
- target closed, quiescent SQLite database files only

This is **not** a full SQLite replacement yet. It is a staged implementation path.

---

## High-Level Architecture

```text
SQLite .db file
      ↑
      │ raw page bytes
      │
shell pager harness
      ↑
      │ ASCII request/response protocol over pipes
      │
Brainfuck engine
```

Responsibilities:

### Shell side
Only:
- read raw bytes from the `.db` file
- write raw bytes back later
- encode bytes as hex
- decode hex back to bytes later
- manage FIFOs

### Brainfuck side
Implements:
- SQLite header parsing
- hex decoding
- page parsing
- B-tree header parsing
- cell pointer parsing
- varint decoding
- schema walking
- eventually page mutation and writes

---

## Phase Plan

## Phase 1: Read-only page-1 inspector

Deliverables:
- shell pager that supports:
  - `H`
  - `R <page_size> <page_no>`
- Brainfuck program that:
  - requests header
  - decodes 100 bytes of hex
  - verifies `SQLite format 3\0`
  - extracts page size
  - extracts page count
  - extracts freelist head/count
  - requests page 1
  - stores page 1 bytes

Success criteria:
- works against a small known SQLite DB
- prints or otherwise exposes decoded header values

## Phase 2: Parse page-1 B-tree header

Deliverables:
- Brainfuck parser for B-tree page header
- special handling for page 1:
  - B-tree header starts at byte offset 100, not 0

Success criteria:
- detect page type
- read freeblock offset
- read cell count
- read start of cell content area
- read fragmented free bytes

## Phase 3: Parse cell pointer array

Deliverables:
- Brainfuck code to iterate over the page's cell pointer array
- extract 2-byte big-endian offsets for each cell

Success criteria:
- dump or inspect all cell offsets on page 1

## Phase 4: Walk `sqlite_schema`

Deliverables:
- decode table-leaf cells from the `sqlite_schema` table
- parse record payload enough to identify:
  - object type
  - name
  - tbl_name
  - rootpage
  - SQL text

Success criteria:
- extract at least one user table root page

## Phase 5: Read one user table

Deliverables:
- traverse a table B-tree
- decode rowid table leaf cells
- parse records from one simple table

Success criteria:
- extract rows from a table with simple schema, ideally fixed small text/int fields

## Phase 6: Controlled writes

Deliverables:
- shell pager adds write command
- Brainfuck can rewrite one page
- initially only support carefully constrained writes

Success criteria:
- write to a known tiny DB copy without immediate corruption

---

## Recommended Repository Layout

```text
bf-sqlite/
  README.md
  docs/
    architecture.md
    cursor_build_plan.md
    sqlite_subset.md
    page_layout_notes.md
  scripts/
    pager.sh
    run_inspector.sh
    make_test_db.sh
    inspect_header.sh
  bf/
    phase1_header_inspector.bf
    phase2_page1_parser.bf
    phase3_cellptrs.bf
    phase4_schema_walk.bf
    lib_hex_decode.bf
    lib_big_endian.bf
    lib_ascii_io.bf
  tests/
    fixtures/
      tiny.db
      tiny.sql.txt
      expected_header.txt
    smoke/
      test_header.sh
      test_page1.sh
  scratch/
    notes.md
```

---

## Runtime Protocol

The shell pager communicates using line-based ASCII commands.

### Request: header
```text
H
```

Response:
- 200 lowercase hex chars
- newline

Meaning:
- first 100 bytes of the SQLite file header

### Request: page read
```text
R <page_size> <page_no>
```

Example:
```text
R 4096 1
```

Response:
- `2 * page_size` lowercase hex chars
- newline

### Future request: page write
Not yet enabled in phase 1.

Possible form:
```text
W <page_size> <page_no> <hex_data>
```

---

## Shell Pager Implementation Target

Cursor should create `scripts/pager.sh` approximately like this:

```bash
#!/usr/bin/env bash
set -euo pipefail

DB=${1:?usage: ./pager.sh path/to/db}
REQ=${REQ:-pager.req}
RES=${RES:-pager.res}

rm -f "$REQ" "$RES"
mkfifo "$REQ" "$RES"

cleanup() {
  rm -f "$REQ" "$RES"
}
trap cleanup EXIT

while IFS= read -r line < "$REQ"; do
  set -- $line
  cmd=${1:-}

  case "$cmd" in
    H)
      dd if="$DB" bs=100 count=1 status=none \
        | od -An -tx1 -v \
        | tr -d ' \n' \
        > "$RES"
      printf '\n' > "$RES"
      ;;

    R)
      page_size=${2:?missing page_size}
      page_no=${3:?missing page_no}
      skip=$((page_no - 1))
      dd if="$DB" bs="$page_size" skip="$skip" count=1 status=none \
        | od -An -tx1 -v \
        | tr -d ' \n' \
        > "$RES"
      printf '\n' > "$RES"
      ;;

    *)
      printf 'ERR unknown command\n' > "$RES"
      ;;
  esac
done
```

Notes:
- page numbers are 1-based
- this is read-only
- later writes should use `dd ... conv=notrunc`

---

## Brainfuck Module Breakdown

Cursor should not try to build the full engine as one monolith immediately.

Break it into conceptual modules, even if final composition is a single `.bf` file.

### Module 1: ASCII output helpers
Responsibilities:
- emit literal command text like `H\n`
- emit `R `
- emit decimal integers if needed later

### Module 2: Line reader
Responsibilities:
- read one response line from stdin
- stop at newline
- store raw ASCII hex chars in tape memory

### Module 3: Hex decoder
Responsibilities:
- map ASCII:
  - `0..9` -> `0..9`
  - `a..f` -> `10..15`
- combine every pair into one byte

### Module 4: Big-endian field decoder
Responsibilities:
- read 2-byte and 4-byte big-endian fields
- initially keep them as byte tuples rather than full decimal integers

### Module 5: SQLite header validator
Responsibilities:
- compare first 16 bytes to:
  - `SQLite format 3\0`
- reject if mismatch

### Module 6: Page 1 parser
Responsibilities:
- parse B-tree header beginning at byte 100
- extract page type and cell count

### Module 7: Cell pointer iterator
Responsibilities:
- iterate through 2-byte offsets
- record per-cell pointers

---

## Suggested Brainfuck Tape Layout

This is only a recommended layout. Cursor can adapt it if needed.

```text
0..31      general registers / counters / temps
32..63     ASCII command construction area
64..511    raw hex input buffer
512..767   decoded header bytes / page bytes start
768..1023  decoded page header scratch
1024..1535 cell pointer array / parsed offsets
1536..2047 schema parsing scratch
```

Recommended named logical cells:

```text
0   current char
1   temp
2   temp
3   high nibble
4   low nibble
5   decoded byte
6   loop counter
7   compare flag
8   page type
9   cell count high
10  cell count low
11  page-size high
12  page-size low
13  error flag
14  newline flag
15  pointer scratch
```

Keep values byte-oriented as long as possible.

Avoid converting to decimal too early.

---

## SQLite Facts the BF Engine Must Respect

### File header
The first 100 bytes of the file are the SQLite database header.

Important offsets:

- `0..15`: magic string `SQLite format 3\0`
- `16..17`: page size, big-endian 2-byte
- `18`: file format write version
- `19`: file format read version
- `24..27`: file change counter
- `28..31`: database size in pages
- `32..35`: first freelist trunk page
- `36..39`: freelist page count
- `56..59`: text encoding

### Page numbering
- SQLite pages are numbered from 1
- page 1 begins at file offset 0
- page N begins at `(N-1) * page_size`

### Page 1 special case
- page 1 includes the 100-byte file header
- therefore page 1's B-tree header starts at byte 100

### B-tree page types
- `2` interior index
- `5` interior table
- `10` leaf index
- `13` leaf table

For early milestones, only support:
- page 1 as a table b-tree page if applicable
- leaf table pages
- maybe interior table pages later

---

## Initial Scope Restrictions

Cursor should assume:

- rollback-journal mode only
- not WAL mode
- no concurrent access
- no auto-vacuum
- small test DBs
- UTF-8 only
- ideally one tiny user table
- avoid overflow pages at first

Reject databases if:
- write/read versions are not both `1`
- page size is unexpected
- file header magic does not match

---

## Test Fixture Strategy

Cursor should create scripts to generate tiny databases externally if available, but the runtime must not depend on `sqlite3`.

So:
- fixture DBs can be pre-generated and committed
- expected metadata can be committed as text fixtures

Suggested fixture set:

### `tests/fixtures/tiny.db`
A tiny SQLite DB with:
- one table
- one or two short rows
- small page count

### `tests/fixtures/expected_header.txt`
Contains expected values:
- page size
- page count
- freelist head
- freelist count
- read version
- write version

### `tests/fixtures/page1_hex.txt`
Optional full known-good page 1 hex dump for reference

---

## Suggested Smoke Tests

### Smoke test 1: pager header
Shell test:
- run pager
- send `H`
- verify response length is 200
- verify prefix matches hex for `SQLite format 3\0`

### Smoke test 2: page read
Shell test:
- send `R <pagesize> 1`
- verify response length equals `2 * page_size`

### Smoke test 3: BF header parse
Run BF program against pager:
- expect decoded page size bytes
- expect success flag for valid SQLite header

---

## Prompting Guidance for Cursor

Use these instructions when asking Cursor to continue:

### Good prompt style
- “Implement only phase 1.”
- “Do not attempt writes yet.”
- “Keep shell pager SQLite-agnostic.”
- “Do not add external dependencies.”
- “Prefer explicit file creation over abstract discussion.”
- “Show the exact `.bf` program and shell scripts.”

### Good incremental prompts
1. “Create `scripts/pager.sh` and `scripts/run_inspector.sh` for phase 1.”
2. “Create a minimal Brainfuck program that emits `H\n`, reads one line, and stores it.”
3. “Extend the BF program to hex-decode 200 chars into 100 bytes.”
4. “Add validation of `SQLite format 3\0`.”
5. “Add extraction of page-size bytes at offsets 16 and 17.”

### Bad prompt style
- “Build the whole SQLite engine in Brainfuck.”
- “Make it production ready.”
- “Support all SQLite databases.”

That will cause drift and hallucinated completeness.

---

## Exact Near-Term Tasks for Cursor

Cursor should now implement these in order.

### Task 1
Create:

- `scripts/pager.sh`
- `scripts/run_inspector.sh`

`run_inspector.sh` should:
- start pager
- open FIFOs
- send `H`
- read and print the header hex
- clean up

### Task 2
Create:

- `bf/phase1_header_inspector.bf`

First version only needs to:
- write `H\n`
- read response line

### Task 3
Extend `phase1_header_inspector.bf` to:
- decode hex pairs into bytes
- store 100 decoded bytes

### Task 4
Add header validation:
- compare bytes `0..15` with `SQLite format 3\0`

### Task 5
Add extraction of:
- page size bytes
- read version
- write version
- page count bytes
- freelist head bytes
- freelist count bytes

### Task 6
Create test notes documenting:
- memory map used
- assumptions
- known limits

---

## Longer-Term Tasks

After phase 1 is working:

### Task 7
Request page 1:
```text
R <page_size> 1
```

### Task 8
Parse page 1 B-tree header from byte offset 100

### Task 9
Extract cell count and cell pointer array

### Task 10
Decode first `sqlite_schema` cells

### Task 11
Locate a user table root page

### Task 12
Traverse that table and read rows

Only after all of that:
- consider write support

---

## What Not to Claim

Do not describe the project as:
- “SQLite in Brainfuck”
- “SQLite-compatible”
- “full SQLite engine”

Accurate description:
- “SQLite file-format reader/writer core in Brainfuck”
- “SQLite-inspired storage engine tooling in Brainfuck”
- “Brainfuck SQLite page parser via shell pager”

---

## Final Direction

The strategic objective is:

> Keep the shell side stupid and tiny. Push all semantics upward into Brainfuck.

That means:
- shell moves bytes
- Brainfuck understands SQLite

That is the cleanest and most extreme version of this project under the current constraints.
