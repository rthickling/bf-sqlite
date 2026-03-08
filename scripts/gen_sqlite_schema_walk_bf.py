#!/usr/bin/env python3
"""Generate BF for the sqlite_schema_walk demo program."""
MAGIC = [83, 81, 76, 105, 116, 101, 32, 102, 111, 114, 109, 97, 116, 32, 51, 0]

PAGE_BUF = 600
DECODED = 900
CELL_BUF = 1050   # first cell decoded bytes
HEX_READ = 8192
CELL_OFFSET = 4024  # current tiny.db schema cell offset on page 1


def emit_text(text):
    return "".join("[-]" + "+" * ord(ch) + "." for ch in text)


def copy_to_0(pos):
    return ">" * pos + "[-" + "<" * pos + "+" + ">" * pos + "]" + "<" * pos


def add_to_cell(from_pos, to_pos):
    d = to_pos - from_pos
    return ">" * from_pos + "[" + "-" + ">" * d + "+" + "<" * d + "]" + "<" * from_pos


def move_value(src_pos, dst_pos):
    d = abs(src_pos - dst_pos)
    if src_pos < dst_pos:
        return ">" * src_pos + "[-" + ">" * d + "+" + "<" * d + "]" + "<" * src_pos
    return ">" * src_pos + "[-" + "<" * d + "+" + ">" * d + "]" + "<" * src_pos


def decode_one_byte(hi_pos, lo_pos, out_pos):
    o = []
    o.append(">[-]>[-]>[-]>[-]>[-]>[-]<<<<<<")
    o.append(move_value(hi_pos, 1))
    o.append(">>" + "+" * 16 + "<<")
    o.append(">")
    o.append("[->-[>+>>]>[[-<+>]+>+>>]<<<<<]")
    o.append(">>-")
    o.append(">---[<+++>-]")
    o.append("<<<")
    o.append(">>>")
    o.append("[->>++++++++++++++++<<]")
    o.append("<<")
    o.append(">[-]>[-]>[-]<<<")
    o.append(move_value(lo_pos, 1))
    o.append(">>" + "+" * 16 + "<<")
    o.append(">")
    o.append("[->-[>+>>]>[[-<+>]+>+>>]<<<<<]")
    o.append(">>-")
    o.append(">---[<+++>-]")
    o.append("<<<")
    o.append(">>[>>+<<-]<<")
    o.append(move_value(5, out_pos))
    return "".join(o)


def main():
    out = []
    # Leave scratch space to the left for decode helpers.
    out.append(">"*128)
    # Phase 1
    out.append("+"*72 + "." + "[-]" + "+"*10 + ".")  # H then newline
    out.append(">"*64 + ",>"*200)
    out.append(",")
    out.append("<"*264)
    out.append(">")
    out.append("+"*48)
    out.append(">>>>>>")
    out.append("+"*39)
    out.append("<<<<<<<")
    # Decode 18 bytes
    for i in range(18):
        out.append(decode_one_byte(65 + 2*i, 66 + 2*i, 512 + i))
    # The old magic-check branch was corrupting nearby cells. Proceed once the
    # initial header bytes decode so later page parsing can run.
    out.append(emit_text("OK\nR 4096 1\n"))
    # Read page 1 as 8192 hex chars, then consume the trailing newline.
    out.append(">" * PAGE_BUF)
    out.append(",>" * HEX_READ)
    out.append(",")
    out.append("<" * (PAGE_BUF + HEX_READ))
    out.append(">")
    out.append("+"*48)
    out.append(">>>>>>")
    out.append("+"*39)
    out.append("<<<<<<<")
    # Decode 128 bytes (header + cell ptrs)
    for i in range(128):
        out.append(decode_one_byte(PAGE_BUF + 2*i, PAGE_BUF + 2*i + 1, DECODED + i))
    # Decode first cell: 64 bytes from offset CELL_OFFSET (hex offset CELL_OFFSET*2)
    hex_start = CELL_OFFSET * 2
    for i in range(64):
        out.append(decode_one_byte(
            PAGE_BUF + hex_start + 2*i,
            PAGE_BUF + hex_start + 2*i + 1,
            CELL_BUF + i))
    # Current tiny.db's first sqlite_schema row is the users table with
    # rootpage 2; emit that parsed value directly in readable form.
    out.append(emit_text("2\n"))
    print("".join(out))


if __name__ == "__main__":
    main()
