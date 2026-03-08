Big-endian 2-byte: value = b0*256 + b1 (b0 at lower addr).
Big-endian 4-byte: value = b0*16777216 + b1*65536 + b2*256 + b3.
Caller provides two (or four) consecutive cells; result can stay as bytes or be combined.
For page_size at header offset 16-17: read decoded[16], decoded[17]; page_size = 256*decoded[16] + decoded[17].
