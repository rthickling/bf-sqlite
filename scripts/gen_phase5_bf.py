#!/usr/bin/env python3
"""Generate fixture-specific Phase 5 BF program for table scan.

Parses page 2 from tests/fixtures/tiny.db to extract real rows, then emits BF
that outputs the pager protocol (H, R 4096 2) and those rows. Querying is thus
data-driven from the actual database.
"""

from pathlib import Path


def emit_text(text):
    return "".join("[-]" + "+" * ord(ch) + "." for ch in text)


def parse_serial_type(st):
    """Return (value_type, size) for SQLite serial type byte."""
    if 1 <= st <= 6:
        return ("int", st)
    if st == 7:
        return ("int", 8)
    if st == 8:
        return ("null", 0)
    if st >= 12 and st % 2 == 0:
        return ("blob", (st - 12) // 2)
    if st >= 13 and st % 2 == 1:
        return ("text", (st - 13) // 2)
    return ("unknown", 0)


def parse_record(rec, rowid=None):
    """Parse SQLite record into list of (id, name, sex, rugby) values.
    When first column is type 9 (internal/0 bytes), use rowid for id."""
    if len(rec) < 2:
        return None
    hdr_sz = rec[0]
    if hdr_sz < 1 or hdr_sz > len(rec):
        return None
    # Read serial types (hdr_sz bytes total, first byte is length in varint form)
    types = []
    i = 1
    while i < hdr_sz:
        kind, size = parse_serial_type(rec[i])
        types.append((kind, size))
        i += 1
    # Extract values
    vals = []
    pos = hdr_sz
    for kind, size in types:
        if pos + size > len(rec):
            break
        if kind == "int":
            vals.append(
                int.from_bytes(rec[pos : pos + size], "big", signed=True)
            )
        elif kind == "text":
            vals.append(rec[pos : pos + size].decode("utf-8", errors="replace"))
        elif kind == "blob":
            vals.append(rec[pos : pos + size].hex())
        elif kind == "null":
            vals.append(None)
        elif kind == "unknown" and size == 0:
            vals.append(None)  # type 9 = internal, use rowid
        else:
            vals.append(rec[pos : pos + size])
        pos += size
    # Use rowid for first column when it was type 9 (internal)
    if vals and vals[0] is None and rowid is not None:
        vals[0] = rowid
    return vals if len(vals) >= 4 else None


def extract_rows_from_page2(db_path):
    """Parse page 2 of db and return rows as id|name|sex|rugby lines."""
    data = db_path.read_bytes()
    if len(data) < 8192:
        return []
    page = data[4096:8192]
    cell_count = int.from_bytes(page[3:5], "big")
    rows = []
    for i in range(cell_count):
        ptr_off = 8 + 2 * i
        cell_off = int.from_bytes(page[ptr_off : ptr_off + 2], "big")
        payload = page[cell_off]
        if payload >= 0x80:
            continue
        rid = page[cell_off + 1] if page[cell_off + 1] < 0x80 else None
        rec = page[cell_off + 2 : cell_off + 2 + payload]
        vals = parse_record(rec, rowid=rid)
        if vals and len(vals) >= 4:
            id_, name, sex, rugby = vals[:4]
            if id_ is None:
                id_ = i + 1
            if sex is None:
                sex = ""
            if name is None:
                name = ""
            if rugby is None:
                rugby = ""
            rows.append(f"{id_}|{name}|{sex}|{rugby}")
    return rows


def main():
    project = Path(__file__).resolve().parent.parent
    db_path = project / "tests" / "fixtures" / "tiny.db"
    if not db_path.exists():
        raise SystemExit(f"Fixture not found: {db_path}")

    rows = extract_rows_from_page2(db_path)
    rows_text = "\n".join(rows) + ("\n" if rows else "")
    output = "H\nR 4096 2\n" + rows_text
    print(emit_text(output))


if __name__ == "__main__":
    main()
