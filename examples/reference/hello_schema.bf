# hello_schema.bf
# Example: Minimal SQLite schema inspector
# Sends H to pager, reads header, validates magic, extracts page size.
# Output: page size (decimal) and "OK" or "FAIL"
#
# Usage: run with pager connected via FIFOs
#   ./run_example.sh examples/reference/hello_schema.bf path/to/db
#
# 1. Send "H\n" to pager (stdout goes to pager req FIFO)
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++.
++.
# 2. Read response from pager (stdin from pager res FIFO)
# ... read 200 hex chars + newline ...
# 3. Decode first 16 bytes, compare to "SQLite format 3\0"
# 4. Decode bytes 16-17 (page size), output
# (Full implementation in sqlite_header_inspector.bf)
