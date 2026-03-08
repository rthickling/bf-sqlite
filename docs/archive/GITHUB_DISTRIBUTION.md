# GitHub Distribution

## Repository Setup

```bash
cd bf-sqlite
git init
git add .
git commit -m "Initial commit: BF-SQLite architecture and build plan"
git remote add origin https://github.com/YOUR_USERNAME/bf-sqlite.git
git push -u origin main
```

## BF-Only Toolchain (Docker)

`tools/` provides a Dockerfile that builds bf2c and the full toolchain from scratch.

```bash
git clone ... bf-sqlite && cd bf-sqlite
docker build -f tools/Dockerfile -t bf-sqlite .
docker run -it --rm -v $(pwd):/work bf-sqlite ./scripts/run_bf_db.sh my.bf tests/fixtures/tiny.db
```

## What to Include

- All `.bf`, `.sh`, and user-facing `.md` files
- `LICENSE`
- `tests/fixtures/tiny.sql.txt`
- Do **not** commit `tests/fixtures/tiny.db` unless you explicitly want a prebuilt fixture

## Optional: Commit tiny.db for CI convenience

```bash
sqlite3 tests/fixtures/tiny.db < tests/fixtures/tiny.sql.txt
git add -f tests/fixtures/tiny.db
```
