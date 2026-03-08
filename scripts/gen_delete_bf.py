#!/usr/bin/env python3
"""Generate BF program that deletes row 4 from users.

Reads page 2 from tests/fixtures/tiny.db, removes the cell for rowid 4, updates
the page header (cell count and cell content start) and pointer array, and emits
BF that prints: W 4096 2\\n<hex_page>\\n.
"""

from pathlib import Path


def emit_text(text):
    return "".join("[-]" + "+" * ord(ch) + "." for ch in text)


def build_delete_page(db_path, rowid_to_delete=4):
    data = db_path.read_bytes()
    page2 = bytearray(data[4096:8192])

    cell_count = int.from_bytes(page2[3:5], "big")
    cell_offsets = []
    delete_idx = -1
    for i in range(cell_count):
        ptr_off = 8 + 2 * i
        cell_off = int.from_bytes(page2[ptr_off : ptr_off + 2], "big")
        payload = page2[cell_off]
        if payload >= 0x80:
            cell_offsets.append(cell_off)
            continue
        rowid = page2[cell_off + 1]
        if rowid >= 0x80:
            cell_offsets.append(cell_off)
            continue
        cell_offsets.append(cell_off)
        if rowid == rowid_to_delete:
            delete_idx = i
            break

    if delete_idx < 0:
        raise SystemExit(f"Row {rowid_to_delete} not found on page")

    # New pointer array: all except the deleted index
    new_count = cell_count - 1
    new_offsets = [cell_offsets[j] for j in range(cell_count) if j != delete_idx]
    new_cell_start = min(new_offsets)

    page2[3] = new_count >> 8
    page2[4] = new_count & 0xFF
    page2[5] = new_cell_start >> 8
    page2[6] = new_cell_start & 0xFF
    for i, off in enumerate(new_offsets):
        ptr_off = 8 + 2 * i
        page2[ptr_off] = off >> 8
        page2[ptr_off + 1] = off & 0xFF

    return bytes(page2)


def main():
    project = Path(__file__).resolve().parent.parent
    db_path = project / "tests" / "fixtures" / "tiny.db"
    if not db_path.exists():
        raise SystemExit(f"Fixture not found: {db_path}")

    page2 = build_delete_page(db_path)
    hex_page = page2.hex()
    # Split hex into 256-char lines (avoids LINE_MAX ~2048 truncation)
    chunk = 256
    lines = [hex_page[i : i + chunk] for i in range(0, len(hex_page), chunk)]
    output = "W 4096 2\n" + "\n".join(lines) + "\n"
    print(emit_text(output))


if __name__ == "__main__":
    main()
