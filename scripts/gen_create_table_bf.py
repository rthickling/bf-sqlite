#!/usr/bin/env python3
"""Generate a narrow CREATE TABLE BF program for the demo database."""

from __future__ import annotations

import argparse
from pathlib import Path

from create_table_helper import emit_create_table_bf


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Generate BF for a narrow CREATE TABLE demo over the fixture database."
        )
    )
    parser.add_argument("table", help="Table name, for example: log")
    parser.add_argument(
        "columns",
        nargs="+",
        help="Column specs in the form name:INT or name:TEXT",
    )
    parser.add_argument(
        "--db",
        default=None,
        help="Override the fixture database path (defaults to tests/fixtures/tiny.db)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    project = Path(__file__).resolve().parent.parent
    db_path = Path(args.db) if args.db else project / "tests" / "fixtures" / "tiny.db"
    if not db_path.exists():
        raise SystemExit(f"Fixture not found: {db_path}")

    print(emit_create_table_bf(db_path, args.table, args.columns))


if __name__ == "__main__":
    main()
