# Brainfuck-Based SQLite File Access Using Pipes and Core Linux Tools

## Goal

Create a system where a **Brainfuck program can read and write SQLite
`.db` files** without:

-   compiling new C code
-   installing additional packages
-   relying on the `sqlite3` CLI

Only the following are allowed:

-   Brainfuck program
-   pipes / FIFOs
-   core Linux utilities (e.g., `dd`, `od`, `tr`, `printf`, `mkfifo`,
    `stat`)
-   shell scripting

## Core Insight

SQLite databases are **page-based files**.

Important properties:

-   The **database header occupies the first 100 bytes**
-   The **page size is stored at header offset 16--17**
-   Pages are numbered starting at **1**
-   Page N starts at offset:

```{=html}
<!-- -->
```
    (N-1) * page_size

Because SQLite performs **whole‑page reads and writes**, a Brainfuck
system can interact with the database using only:

    dd
    pipes
    hex encoding

The Brainfuck program performs all **database logic**:

-   SQLite header parsing
-   B‑tree traversal
-   varint decoding
-   cell pointer decoding
-   freelist management
-   page mutation

The shell layer only transports pages.

This mirrors SQLite's own architecture where the **pager layer mediates
access between the B‑tree layer and the filesystem**.

------------------------------------------------------------------------

# Architecture

    SQLite .db file
            ↑
            │ dd page reads/writes
            │
    Shell pager (bash)
            ↑
            │ request / response protocol
            │
    Brainfuck database engine

The shell pager does **no SQLite interpretation**.

It only moves raw page bytes.

------------------------------------------------------------------------

# Pager Request Protocol

The Brainfuck engine communicates with the pager using ASCII commands.

Requests:

    H

Return first **100 bytes** of the database header as hex.

    R <page_size> <page_number>

Return an entire page as hex.

Example:

    R 4096 3

Responses:

    <hex string>

Errors:

    ERR message

------------------------------------------------------------------------

# Shell Pager Implementation

Example `pager.sh`:

``` bash
#!/usr/bin/env bash
set -euo pipefail

DB="$1"

REQ=pager.req
RES=pager.res

rm -f "$REQ" "$RES"
mkfifo "$REQ" "$RES"

while IFS= read -r line < "$REQ"; do
    set -- $line
    cmd=$1

    case "$cmd" in
        H)
            dd if="$DB" bs=100 count=1 status=none |
            od -An -tx1 -v |
            tr -d ' \n' > "$RES"
            printf '\n' > "$RES"
        ;;

        R)
            pagesize=$2
            page=$3
            skip=$((page-1))

            dd if="$DB" bs="$pagesize" skip="$skip" count=1 status=none |
            od -An -tx1 -v |
            tr -d ' \n' > "$RES"
            printf '\n' > "$RES"
        ;;

        *)
            printf "ERR\n" > "$RES"
        ;;
    esac

done
```

------------------------------------------------------------------------

# Brainfuck Engine Responsibilities

The Brainfuck program implements:

### 1. Header Parsing

Validate magic string:

    SQLite format 3\0

Decode:

  Offset   Field
  -------- ---------------------
  16--17   page size
  24--27   change counter
  28--31   page count
  32--35   freelist head
  36--39   freelist page count

All integers are **big‑endian**.

------------------------------------------------------------------------

### 2. Hex Decoding

Pager responses are hex encoded.

Brainfuck must convert:

    hex pair -> byte

Example:

    a7 -> (10 * 16) + 7

------------------------------------------------------------------------

### 3. Page Access

Brainfuck sends:

    R <page_size> N

Pager returns the entire page as hex.

Brainfuck stores it internally and parses it.

------------------------------------------------------------------------

### 4. SQLite Page Layout

Important page types:

  Type   Meaning
  ------ ----------------
  2      interior index
  5      interior table
  10     leaf index
  13     leaf table

For **page 1**, the B‑tree header begins at byte **100**, not byte 0.

------------------------------------------------------------------------

### 5. B‑Tree Traversal

Brainfuck must:

1.  Read page header
2.  Read cell pointer array
3.  Follow child pointers
4.  Decode row records

------------------------------------------------------------------------

### 6. Record Decoding

SQLite records use:

-   **varints**
-   **serial types**
-   **payload headers**

Brainfuck must implement:

-   varint decoding
-   payload parsing

------------------------------------------------------------------------

# Recommended Development Phases

### Phase 1 --- Header Inspector

Brainfuck:

-   request header
-   decode page size
-   verify magic string

### Phase 2 --- Page Reader

Brainfuck:

-   request page 1
-   parse B‑tree header

### Phase 3 --- Schema Walker

Brainfuck:

-   read `sqlite_schema`
-   extract table root pages

### Phase 4 --- Table Scan

Brainfuck:

-   traverse table B‑trees
-   decode records

### Phase 5 --- Writes

Brainfuck:

-   allocate pages
-   update freelist
-   rewrite leaf pages

------------------------------------------------------------------------

# Important Constraints

Use only databases that are:

-   **not in WAL mode**
-   **not concurrently accessed**
-   **small**
-   **no auto‑vacuum**

This avoids ptrmap pages and journal complexity.

------------------------------------------------------------------------

# Key Design Principle

Push **all intelligence into Brainfuck**.

Shell tools only move bytes.

    Brainfuck = database engine
    Shell = disk transport

This is the maximum possible Brainfuck purity while still interacting
with a real SQLite database file.

------------------------------------------------------------------------

# Final Outcome

The system becomes:

    SQLite file
         ↑
         │ dd
         │
    Shell pager
         ↑
         │ pipes
         │
    Brainfuck SQLite engine

This architecture achieves the original goal:

> Reading and writing SQLite database files from Brainfuck using only
> pipes and core Linux commands.
