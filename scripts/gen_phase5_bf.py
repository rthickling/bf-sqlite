#!/usr/bin/env python3
"""Generate Phase 5 BF program for a full demo-table scan."""

from pathlib import Path

from select_projection import emit_projection_bf


def main():
    project = Path(__file__).resolve().parent.parent
    db_path = project / "tests" / "fixtures" / "tiny.db"
    if not db_path.exists():
        raise SystemExit(f"Fixture not found: {db_path}")

    print(emit_projection_bf(db_path, "users", ["id", "name", "sex", "rugby"]))


if __name__ == "__main__":
    main()
