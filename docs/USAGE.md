# Using BF-SQLite in Your BrainFuck Programs

This is the integration guide: what your BrainFuck program has to say, what it gets back, and which helper scripts are worth knowing about.

## Fast path

Docker-first:

```bash
./bin/build-image
./bin/run-bf-db my_program.bf tests/fixtures/tiny.db
```

Optional:

```bash
export PATH="$PWD/bin:$PATH"
build-image
run-bf-db my_program.bf tests/fixtures/tiny.db
```

Local toolchain:

```bash
./scripts/build_bf.sh
./scripts/run_bf_db.sh my_program.bf tests/fixtures/tiny.db
```

The local wrapper uses `python3` to route pager commands and responses.

If `tests/fixtures/tiny.db` is missing, `run_bf_db.sh` will try to create it from `tests/fixtures/tiny.sql.txt`.

## Pager model

Your BrainFuck program:

- writes commands to `stdout`
- reads pager responses from `stdin`

The pager itself is `scripts/pager.sh`. In normal use you do not run it directly; `scripts/run_bf_db.sh` wires everything together with FIFOs.

## Protocol

| Command | Meaning | Response |
|---------|---------|----------|
| `H` | Read the 100-byte SQLite header | 200 hex chars + newline |
| `R <page_size> <page_no>` | Read one page | `page_size * 2` hex chars + newline |
| `W <page_size> <page_no>` | Write one page | `OK\n` after page hex is received |

Example flow:

1. Send `H\n`
2. Read 200 hex chars plus newline
3. Send `R 4096 1\n`
4. Read 8192 hex chars plus newline

Hex rules:

- each byte becomes two lowercase hex chars
- a 4096-byte page becomes 8192 chars
- `W` accepts 256-char hex lines to avoid shell line-length issues

## Minimal BF shape

```brainfuck
# Emit H then newline
++++++++[>+++++++++<-]>.
[-]++++++++++.

# Read the response line
# ... your read loop here ...
```

The smallest runnable example is `examples/01_hello_header.bf`.

## Helpful building blocks

- `bf/lib_hex_decode.bf` for hex-pair to byte decoding
- `scripts/emit_bf.py` for generating BF that prints literal command text
- `scripts/build_bf.sh` for regenerating and compiling the phase programs

Example:

```bash
python3 scripts/emit_bf.py "R 4096 2\n"
```

## Phase programs

The built phase binaries are the easiest way to see the current capability:

- `phase1_header_inspector`
- `phase2_header_parser`
- `phase3_page1_parser`
- `phase4_schema_walk`
- `phase5_table_scan`
- `phase6_insert`
- `phase7_update`
- `phase8_delete`

If you call one of these through `scripts/run_bf_db.sh` and it is missing, the script will try to build it for you.

## Demo schema

The checked-in SQL fixture is:

```sql
CREATE TABLE users (id INT, name TEXT, sex TEXT, rugby TEXT);
```

with rows:

```text
1|alice|F|France
2|bob|M|England
3|bert|M|Australia
4|jude|M|USA
```

The current generators and write demos target this schema.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `bf2c not found` | Set `BF2C=/path/to/bf2c` or use Docker |
| `tiny.db` missing | Install `sqlite3` or use the Docker image |
| large phases fail under `gcc` | Use `GCC="clang -O0"` |
| pager hangs | Make sure your BF program consumes the whole response before sending the next command |

## See also

- [README.md](../README.md)
- [examples/README.md](../examples/README.md)
- [tests/TESTS.md](../tests/TESTS.md)
- [PHASE2_SPEC.md](PHASE2_SPEC.md)
- [DETAILED_BUILD_PLAN.md](DETAILED_BUILD_PLAN.md)
