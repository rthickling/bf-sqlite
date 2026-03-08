# template.bf - Minimal template for a BF program that talks to the SQLite pager
#
# Protocol: write commands to stdout, read hex responses from stdin.
# Commands: H (header), R <page_size> <page_no> (read page), W <page_size> <page_no> (write page)
#
# Run: ./bin/run-bf-db examples/reference/template.bf path/to/database.db
#
# This example: sends H, reads 200 hex chars, prints OK
#
# Emit "H" (72)
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++.
# Emit newline (10)
+++++++++++++++++.
# TODO: Read 200 hex chars + newline from stdin (pager response)
# For each char: , (read) then process or discard
# Stop when you read newline (10)
# ... your read loop here ...
# For now, minimal: just print "OK" and exit
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++.
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++.
+++++++++++++++++.
