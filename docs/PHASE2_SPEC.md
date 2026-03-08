# Phase 2: Header Parser Spec

## Input
- 100 decoded bytes at tape 512..611 (from Phase 1 hex decode)

## Magic validation
- Bytes 512..527 must equal: 83 81 76 105 116 101 32 102 111 114 109 97 116 32 51 0  
  (`SQLite format 3\0`)

## Field extraction (big-endian)
- 516..517: page size (2 bytes) → 256*b[16] + b[17]
- 518: file format write version
- 519: file format read version  
- 524..527: page count (4 bytes)
- 532..535: freelist head
- 536..539: freelist count

## Output
- Phase 2 program: after decode + magic check, output "OK" plus page_size (decimal ASCII, from bytes 16–17 big-endian) or "FAIL" plus newline. Page size is output as up to 5 digits (e.g. 4096 or 04096).
