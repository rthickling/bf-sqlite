#!/usr/bin/env python3
"""Generate BF program that inserts row (5, 'chip', 'M', 'Wales') into users.

Reads page 2 from tests/fixtures/tiny.db, builds the modified page with the new
cell, and emits BF that prints: W 4096 2\\n<hex_page>\\n to the pager.
"""

from pathlib import Path


def emit_text(text):
    return "".join("[-]" + "+" * ord(ch) + "." for ch in text)


def build_insert_page(db_path):
    data = db_path.read_bytes()
    page2 = bytearray(data[4096:8192])

    cell_count = int.from_bytes(page2[3:5], "big")
    cell_start = int.from_bytes(page2[5:7], "big")

    # Record: header 05 01 15 0f 17 (4 cols: INT, TEXT4, TEXT1, TEXT5), values
    record = (
        bytes([5, 0x01, 0x15, 0x0F, 0x17])
        + bytes([5])  # id
        + b"chip"
        + b"M"
        + b"Wales"
    )
    cell = bytes([0x10, 0x05]) + record  # payload 16, rowid 5
    assert len(cell) == 18

    new_cell_start = cell_start - len(cell)
    page2[4] = (cell_count + 1) & 0xFF
    page2[5] = new_cell_start >> 8
    page2[6] = new_cell_start & 0xFF
    ptr_off = 8 + 2 * cell_count
    page2[ptr_off] = new_cell_start >> 8
    page2[ptr_off + 1] = new_cell_start & 0xFF
    page2[ptr_off + 1] = new_cell_start & 0xFF
    page2[new_cell_start : new_cell_start + len(cell)] = cell

    return bytes(page2)


def main():
    project = Path(__file__).resolve().parent.parent
    db_path = project / "tests" / "fixtures" / "tiny.db"
    if not db_path.exists():
        raise SystemExit(f"Fixture not found: {db_path}")

    page2 = build_insert_page(db_path)
    hex_page = page2.hex()
    # Split hex into 256-char lines (avoids LINE_MAX ~2048 truncation)
    chunk = 256
    lines = [hex_page[i : i + chunk] for i in range(0, len(hex_page), chunk)]
    output = "W 4096 2\n" + "\n".join(lines) + "\n"
    print(emit_text(output))


if __name__ == "__main__":
    main()
