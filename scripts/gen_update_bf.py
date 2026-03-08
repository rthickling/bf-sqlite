#!/usr/bin/env python3
"""Generate BF program that updates row 4 in users: jude -> judy.

Reads page 2 from tests/fixtures/tiny.db, finds the cell for rowid 4, replaces
the name in-place (same length), and emits BF that prints: W 4096 2\\n<hex_page>\\n.
"""

from pathlib import Path


def emit_text(text):
    return "".join("[-]" + "+" * ord(ch) + "." for ch in text)


def build_update_page(db_path, rowid_to_update=4, old_name=b"jude", new_name=b"judy"):
    if len(old_name) != len(new_name):
        raise ValueError("Update only supports same-length replacement")
    data = db_path.read_bytes()
    page2 = bytearray(data[4096:8192])

    cell_count = int.from_bytes(page2[3:5], "big")
    for i in range(cell_count):
        ptr_off = 8 + 2 * i
        cell_off = int.from_bytes(page2[ptr_off : ptr_off + 2], "big")
        # Varint payload size (single byte)
        payload = page2[cell_off]
        if payload >= 0x80:
            continue  # multi-byte varint, skip
        # Varint rowid (single byte)
        rowid_off = cell_off + 1
        rowid = page2[rowid_off]
        if rowid >= 0x80:
            continue
        if rowid != rowid_to_update:
            continue
        # Record starts at cell_off + 2
        rec_off = cell_off + 2
        record = bytes(page2[rec_off : rec_off + payload])
        # Replace old_name with new_name in record (after header; id is first value)
        # Header: 1 byte size + serial types. For (id, name, sex, rugby): 05 01 15 0f 13
        # Values: 1 byte id, then name (4 bytes jude), 1 byte sex, 3 bytes rugby
        idx = record.find(old_name)
        if idx != -1:
            page2[rec_off + idx : rec_off + idx + len(new_name)] = new_name
            break
    return bytes(page2)


def main():
    project = Path(__file__).resolve().parent.parent
    db_path = project / "tests" / "fixtures" / "tiny.db"
    if not db_path.exists():
        raise SystemExit(f"Fixture not found: {db_path}")

    page2 = build_update_page(db_path)
    hex_page = page2.hex()
    # Split hex into 256-char lines (avoids LINE_MAX ~2048 truncation)
    chunk = 256
    lines = [hex_page[i : i + chunk] for i in range(0, len(hex_page), chunk)]
    output = "W 4096 2\n" + "\n".join(lines) + "\n"
    print(emit_text(output))


if __name__ == "__main__":
    main()
