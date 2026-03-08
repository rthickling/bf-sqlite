#!/usr/bin/env python3
"""Helpers for narrow CREATE TABLE demos."""

from __future__ import annotations

import re
from pathlib import Path

PAGE_SIZE = 4096
SUPPORTED_AFFINITIES = {"INT", "TEXT"}
IDENTIFIER_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*\Z")


def emit_text(text: str) -> str:
    return "".join("[-]" + "+" * ord(ch) + "." for ch in text)


def validate_identifier(name: str, label: str) -> str:
    if not IDENTIFIER_RE.fullmatch(name):
        raise SystemExit(
            f"Invalid {label}: {name!r}. Use letters, digits, and underscores only, "
            "and do not start with a digit."
        )
    return name


def parse_column_specs(column_specs: list[str]) -> list[tuple[str, str]]:
    if not column_specs:
        raise SystemExit("At least one column is required")

    columns: list[tuple[str, str]] = []
    seen: set[str] = set()
    for spec in column_specs:
        if ":" not in spec:
            raise SystemExit(
                f"Invalid column spec: {spec!r}. Use the form name:INT or name:TEXT."
            )
        name, affinity = spec.split(":", 1)
        name = validate_identifier(name, "column name")
        affinity = affinity.upper()
        if affinity not in SUPPORTED_AFFINITIES:
            supported = ", ".join(sorted(SUPPORTED_AFFINITIES))
            raise SystemExit(
                f"Unsupported affinity: {affinity}. Supported affinities: {supported}"
            )
        if name in seen:
            raise SystemExit(f"Duplicate column name: {name}")
        seen.add(name)
        columns.append((name, affinity))
    return columns


def build_create_table_sql(table: str, columns: list[tuple[str, str]]) -> str:
    validate_identifier(table, "table name")
    if not columns:
        raise SystemExit("At least one column is required")
    cols = ", ".join(f"{name} {affinity}" for name, affinity in columns)
    return f"CREATE TABLE {table} ({cols})"


def text_serial_type(value: bytes) -> int:
    return 13 + 2 * len(value)


def encode_schema_record(table: str, new_rootpage: int, sql: str) -> bytes:
    type_value = b"table"
    table_value = table.encode("utf-8")
    sql_value = sql.encode("utf-8")

    serial_types = [
        text_serial_type(type_value),
        text_serial_type(table_value),
        text_serial_type(table_value),
        0x01,  # small integer rootpage
        text_serial_type(sql_value),
    ]
    header_size = 1 + len(serial_types)
    if header_size >= 0x80:
        raise SystemExit("Schema record header too large for narrow demo")

    record = bytes([header_size, *serial_types])
    record += type_value
    record += table_value
    record += table_value
    if not (0 <= new_rootpage <= 0x7F):
        raise SystemExit("Root page too large for narrow demo")
    record += bytes([new_rootpage])
    record += sql_value
    return record


def build_schema_cell(rowid: int, table: str, new_rootpage: int, sql: str) -> bytes:
    record = encode_schema_record(table, new_rootpage, sql)
    payload_size = len(record)
    if payload_size >= 0x80:
        raise SystemExit("Schema payload too large for narrow demo")
    if not (0 <= rowid <= 0x7F):
        raise SystemExit("Schema rowid too large for narrow demo")
    return bytes([payload_size, rowid]) + record


def build_empty_table_leaf_page(page_size: int) -> bytes:
    page = bytearray(page_size)
    page[0] = 0x0D  # leaf table b-tree page
    page[5:7] = page_size.to_bytes(2, "big")
    return bytes(page)


def next_schema_rowid(page1: bytes) -> int:
    cell_count = int.from_bytes(page1[103:105], "big")
    rowids: list[int] = []
    for i in range(cell_count):
        ptr_off = 108 + 2 * i
        cell_off = int.from_bytes(page1[ptr_off : ptr_off + 2], "big")
        rowid = page1[cell_off + 1]
        if rowid < 0x80:
            rowids.append(rowid)
    return (max(rowids) if rowids else 0) + 1


def insert_schema_cell(page1: bytes, cell: bytes) -> bytes:
    page = bytearray(page1)
    cell_count = int.from_bytes(page[103:105], "big")
    cell_start = int.from_bytes(page[105:107], "big")
    pointer_end = 108 + 2 * cell_count
    new_cell_start = cell_start - len(cell)
    if new_cell_start < pointer_end + 2:
        raise SystemExit(
            "sqlite_schema page does not have enough free space for a new table"
        )

    page[new_cell_start : new_cell_start + len(cell)] = cell
    page[103:105] = (cell_count + 1).to_bytes(2, "big")
    page[105:107] = new_cell_start.to_bytes(2, "big")
    ptr_off = 108 + 2 * cell_count
    page[ptr_off : ptr_off + 2] = new_cell_start.to_bytes(2, "big")
    return bytes(page)


def build_create_table_pages(
    db_path: Path, table: str, column_specs: list[str]
) -> tuple[int, bytes, int, bytes, str]:
    table = validate_identifier(table, "table name")
    columns = parse_column_specs(column_specs)
    sql = build_create_table_sql(table, columns)

    data = bytearray(db_path.read_bytes())
    page_size = int.from_bytes(data[16:18], "big")
    if page_size != PAGE_SIZE:
        raise SystemExit(
            f"Unsupported page size: {page_size}. Supported page size: {PAGE_SIZE}"
        )

    page_count = int.from_bytes(data[28:32], "big")
    new_rootpage = page_count + 1
    page1 = bytes(data[:page_size])

    rowid = next_schema_rowid(page1)
    schema_cell = build_schema_cell(rowid, table, new_rootpage, sql)
    new_page1 = insert_schema_cell(page1, schema_cell)

    change_counter = int.from_bytes(data[24:28], "big") + 1
    schema_cookie = int.from_bytes(data[40:44], "big") + 1
    header = bytearray(new_page1[:100])
    header[24:28] = change_counter.to_bytes(4, "big")
    header[28:32] = new_rootpage.to_bytes(4, "big")
    header[40:44] = schema_cookie.to_bytes(4, "big")
    header[92:96] = change_counter.to_bytes(4, "big")
    new_page1 = bytes(header) + new_page1[100:]

    new_root_page = build_empty_table_leaf_page(page_size)
    return 1, new_page1, new_rootpage, new_root_page, sql


def chunk_hex_lines(data: bytes, chunk_size: int = 256) -> list[str]:
    hex_page = data.hex()
    return [hex_page[i : i + chunk_size] for i in range(0, len(hex_page), chunk_size)]


def build_create_table_output(db_path: Path, table: str, column_specs: list[str]) -> str:
    page1_no, page1, new_rootpage, root_page, _sql = build_create_table_pages(
        db_path, table, column_specs
    )
    output_lines = [f"W {PAGE_SIZE} {page1_no}"]
    output_lines.extend(chunk_hex_lines(page1))
    output_lines.append(f"W {PAGE_SIZE} {new_rootpage}")
    output_lines.extend(chunk_hex_lines(root_page))
    return "\n".join(output_lines) + "\n"


def emit_create_table_bf(db_path: Path, table: str, column_specs: list[str]) -> str:
    return emit_text(build_create_table_output(db_path, table, column_specs))
