#!/usr/bin/env python3
"""Helpers for fixture-backed SELECT-style projection demos."""

from __future__ import annotations

from pathlib import Path

PAGE_SIZE = 4096
TABLE_PAGES = {"users": 2}
TABLE_COLUMNS = {"users": ["id", "name", "sex", "rugby"]}


def emit_text(text: str) -> str:
    return "".join("[-]" + "+" * ord(ch) + "." for ch in text)


def parse_serial_type(st: int) -> tuple[str, int]:
    """Return (value_type, size) for a SQLite serial type byte."""
    if 1 <= st <= 6:
        return ("int", st)
    if st == 7:
        return ("int", 8)
    if st in (8, 9):
        return ("null", 0)
    if st >= 12 and st % 2 == 0:
        return ("blob", (st - 12) // 2)
    if st >= 13 and st % 2 == 1:
        return ("text", (st - 13) // 2)
    return ("unknown", 0)


def parse_record(rec: bytes, rowid: int | None = None) -> list[object] | None:
    """Parse a SQLite record payload into a list of values.

    This implementation intentionally matches the small demo database shape:
    single-byte header size and serial types, with rowid fallback for the
    internal integer optimization used in the first column.
    """
    if len(rec) < 2:
        return None

    hdr_sz = rec[0]
    if hdr_sz < 1 or hdr_sz > len(rec):
        return None

    types: list[tuple[str, int]] = []
    i = 1
    while i < hdr_sz:
        kind, size = parse_serial_type(rec[i])
        types.append((kind, size))
        i += 1

    vals: list[object] = []
    pos = hdr_sz
    for kind, size in types:
        if pos + size > len(rec):
            break
        if kind == "int":
            vals.append(int.from_bytes(rec[pos : pos + size], "big", signed=True))
        elif kind == "text":
            vals.append(rec[pos : pos + size].decode("utf-8", errors="replace"))
        elif kind == "blob":
            vals.append(rec[pos : pos + size].hex())
        elif kind == "null":
            vals.append(None)
        else:
            vals.append(rec[pos : pos + size])
        pos += size

    if vals and vals[0] is None and rowid is not None:
        vals[0] = rowid

    return vals


def validate_projection(table: str, columns: list[str]) -> tuple[str, list[str]]:
    if table not in TABLE_COLUMNS:
        supported = ", ".join(sorted(TABLE_COLUMNS))
        raise SystemExit(f"Unsupported table: {table}. Supported tables: {supported}")
    if not columns:
        raise SystemExit("At least one column is required")

    if columns == ["*"]:
        return table, TABLE_COLUMNS[table][:]

    valid = TABLE_COLUMNS[table]
    unknown = [column for column in columns if column not in valid]
    if unknown:
        raise SystemExit(
            f"Unknown column(s) for {table}: {', '.join(unknown)}. "
            f"Valid columns: {', '.join(valid)}"
        )

    return table, columns


def extract_table_rows(db_path: Path, table: str) -> list[dict[str, object]]:
    table, columns = validate_projection(table, ["*"])
    data = db_path.read_bytes()
    page_no = TABLE_PAGES[table]
    page_start = (page_no - 1) * PAGE_SIZE
    page_end = page_start + PAGE_SIZE
    if len(data) < page_end:
        return []

    page = data[page_start:page_end]
    cell_count = int.from_bytes(page[3:5], "big")
    rows: list[dict[str, object]] = []

    for i in range(cell_count):
        ptr_off = 8 + 2 * i
        cell_off = int.from_bytes(page[ptr_off : ptr_off + 2], "big")
        payload = page[cell_off]
        if payload >= 0x80:
            continue
        rowid = page[cell_off + 1] if page[cell_off + 1] < 0x80 else None
        rec = page[cell_off + 2 : cell_off + 2 + payload]
        values = parse_record(rec, rowid=rowid)
        if not values or len(values) < len(columns):
            continue

        row = dict(zip(columns, values[: len(columns)]))
        for key in columns:
            if row[key] is None:
                row[key] = ""
        rows.append(row)

    return rows


def project_rows(rows: list[dict[str, object]], columns: list[str]) -> list[str]:
    lines = []
    for row in rows:
        parts = [str(row.get(column, "")) for column in columns]
        lines.append("|".join(parts))
    return lines


def build_projection_output(db_path: Path, table: str, columns: list[str]) -> str:
    table, columns = validate_projection(table, columns)
    rows = extract_table_rows(db_path, table)
    projected = project_rows(rows, columns)
    output = "H\n"
    output += f"R {PAGE_SIZE} {TABLE_PAGES[table]}\n"
    if projected:
        output += "\n".join(projected) + "\n"
    return output


def emit_projection_bf(db_path: Path, table: str, columns: list[str]) -> str:
    return emit_text(build_projection_output(db_path, table, columns))
