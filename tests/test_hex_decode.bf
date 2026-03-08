# test_hex_decode.bf
# Reads hex pair from stdin (e.g. "61"), decodes to byte, outputs result.
# "61" -> 0x61 = 97 = 'a'
# Expected: echo "61" | bf_run test_hex_decode.bf -> outputs 'a'
#
# Minimal implementation: read two chars, decode nibbles, combine, output.
# Placeholder - full hex decoder logic to be implemented in bf/lib_hex_decode.bf

,# read first char (high nibble)
[->+<]
>,# read second char (low nibble)
[->+<]
<<
# TODO: nibble decode (0-9 -> 0-9, a-f -> 10-15)
# TODO: combine high*16 + low
# For now: simple pass-through test - just echo first char
>[-]<
[->+<]
>.
# Newline
++++++++++.