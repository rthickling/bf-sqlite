# Using BF-SQLite in Your BrainFuck Programs

This is the integration guide: what your BrainFuck program has to say, what it gets back, and which helper scripts are worth knowing about.

## Fast path

Docker-first:

```bash
export PATH="$PWD/bin:$PATH"
build-image
run-bf-db my_program.bf tests/fixtures/tiny.db
```

For the built demo programs and tests, the repo now reuses existing executables
and only rebuilds a program when its generator, generated `.bf`, or fixture DB
changed.

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

The pager itself is `scripts/pager.sh`. In normal use you do not run it directly;
`scripts/run_bf_db.sh` and `scripts/run_bf_db.py` wire everything together.

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

## Limited SELECT projection

The repo now includes a small projection step for the demo `users` table. It is
the equivalent of:

```sql
SELECT name, sex FROM users;
```

using the built program:

```bash
export PATH="$PWD/bin:$PATH"
run-bf-db ./sqlite_select_users_name_sex tests/fixtures/tiny.db
```

For other column subsets on the same demo table, generate a BF program with:

```bash
python3 scripts/gen_select_bf.py users name sex > bf/my_select_users_name_sex.bf
run-bf-db bf/my_select_users_name_sex.bf tests/fixtures/tiny.db
```

Current limits:

- demo table only: `users`
- columns must come from `id`, `name`, `sex`, `rugby`
- no `WHERE`, `ORDER BY`, joins, or expressions

This is intentionally a BF-native query helper, not a full SQL parser or SQL
engine.

## Narrow CREATE TABLE demo

The repo also includes one narrow create-table demo. It is the equivalent of:

```sql
CREATE TABLE log (ts INT, value TEXT);
```

using the built program:

```bash
export PATH="$PWD/bin:$PATH"
run-bf-db ./sqlite_create_log_table tests/fixtures/tiny.db
```

For custom table names and simple column lists, generate a BF program with:

```bash
python3 scripts/gen_create_table_bf.py log ts:INT value:TEXT > bf/my_create_log_table.bf
run-bf-db bf/my_create_log_table.bf tests/fixtures/tiny.db
```

Current limits:

- fixed 4096-byte page-size demo path only
- simple table name plus `name:INT` / `name:TEXT` column specs only
- empty table creation only
- no indexes, constraints, `WITHOUT ROWID`, page splits, journaling, or general SQL parsing
- page 1 / `sqlite_schema` must have enough free space for the new schema row

## Helpful building blocks

- `bf/lib_hex_decode.bf` for hex-pair to byte decoding
- `scripts/emit_bf.py` for generating BF that prints literal command text
- `scripts/build_bf.sh` for regenerating and compiling the named SQLite demo programs

Example:

```bash
python3 scripts/emit_bf.py "R 4096 2\n"
```

## Demo programs

The built binaries are the easiest way to see the current capability:

- `sqlite_header_inspector`
- `sqlite_header_parser`
- `sqlite_page1_parser`
- `sqlite_schema_walk`
- `sqlite_table_scan`
- `sqlite_insert`
- `sqlite_update`
- `sqlite_delete`
- `sqlite_create_log_table`
- `sqlite_select_users_name`
- `sqlite_select_users_name_sex`

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
| large generated programs fail under `gcc` | Use `GCC="clang -O0"` for the larger generated programs |
| pager hangs | Make sure your BF program consumes the whole response before sending the next command |

## See also

- [README.md](../README.md)
- [examples/README.md](../examples/README.md)
- [tests/TESTS.md](../tests/TESTS.md)
- [SQLITE_HEADER_PARSER_SPEC.md](SQLITE_HEADER_PARSER_SPEC.md)
- [DETAILED_BUILD_PLAN.md](DETAILED_BUILD_PLAN.md)
