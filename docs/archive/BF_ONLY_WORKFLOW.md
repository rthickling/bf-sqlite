# BF-Only Developer Workflow

**You write BrainFuck.** Everything else—bf2c, gcc, the pager, Python generators—is a tool. You don't need to install or understand them.

## Quick Start (Docker)

1. Build the toolchain image:
   ```bash
   docker build -f tools/Dockerfile -t bf-sqlite .
   ```

2. Edit your `.bf` file.

3. Run it:
   ```bash
   docker run -it --rm -v $(pwd):/work bf-sqlite \
     ./scripts/run_bf_db.sh my_program.bf tests/fixtures/tiny.db
   ```

The container includes bf2c, clang, the pager, and all generators. Your `.bf` is compiled automatically and connected to the database.

## What You Need to Know

- **Your program** sends commands to stdout (`H`, `R 4096 1`, etc.) and reads hex from stdin.
- **Protocol**: See [../USAGE.md](../USAGE.md) for the pager commands.
- **Examples**: `examples/01_hello_header.bf` is the main runnable demo.

## Tools (You Can Ignore These)

| Tool | What it does |
|------|--------------|
| bf2c | Compiles .bf → C |
| gcc/clang | Compiles C → executable |
| pager.sh | Talks to SQLite file on your behalf |
| gen_*.py | Generates BF for phases 2–8 |
| sqlite3 | Creates test database from SQL |

They run inside the Docker image. You edit `.bf` and run the scripts.
