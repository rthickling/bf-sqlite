#!/usr/bin/env python3
"""Generate a limited SELECT-style BF program for the demo database."""

from __future__ import annotations

import argparse
from pathlib import Path

from select_projection import emit_projection_bf


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Generate BF for a limited single-table projection over the demo DB."
        )
    )
    parser.add_argument("table", help="Demo table name, for example: users")
    parser.add_argument(
        "columns",
        nargs="+",
        help="Projected columns, for example: name sex",
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

    print(emit_projection_bf(db_path, args.table, args.columns))


if __name__ == "__main__":
    main()
