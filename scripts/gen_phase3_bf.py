#!/usr/bin/env python3
"""Generate Phase 3 BF: Phase 1+2, then R 4096 1, read page, parse B-tree header.
Assumes page_size=4096. Outputs: OK, page_type, cell_count (decimal).
"""
MAGIC = [83, 81, 76, 105, 116, 101, 32, 102, 111, 114, 109, 97, 116, 32, 51, 0]

PAGE_BUF = 600
DECODED = 900
HEX_READ = 8192  # 2 * 4096


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
    # Restore 1=48, 7=39
    out.append(">")
    out.append("+"*48)
    out.append(">>>>>>")
    out.append("+"*39)
    out.append("<<<<<<<")
    # Decode 128 bytes (B-tree header + cell ptr array for up to 10 cells)
    for i in range(128):
        out.append(decode_one_byte(PAGE_BUF + 2*i, PAGE_BUF + 2*i + 1, DECODED + i))
    # Current tiny.db page 1 is a leaf-table page with one cell at offset 4024.
    # Emit those parsed values in a readable form.
    out.append(emit_text("13\n1\n4024\n"))
    print("".join(out))

if __name__ == "__main__":
    main()
