# 02_request_page.bf - Request header then page 1 (H and R commands)
#
# Demonstrates the protocol structure for H followed by R.
# Full implementation: bf/sqlite_page1_parser.bf (gen_sqlite_page1_parser_bf.py)
#
# Protocol:
#   (1) Send "H\n" -> read 200 hex chars + newline
#   (2) Send "R 4096 1\n" -> read 8192 hex chars + newline
#
# Run the built parser: INSPECTOR=./sqlite_page1_parser ./scripts/run_inspector.sh tests/fixtures/tiny.db
# Expected: OK, R 4096 1, 13, 1, 4024 (page type, cell count, first cell offset)
#
# Command emission (BF that prints "R 4096 1\n"):
# R=82, space=32, 4=52, 0=48, 9=57, 6=54, space=32, 1=49, newline=10
