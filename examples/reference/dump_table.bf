# dump_table.bf
# Example: Dump all rows from a user table
# Usage: ./run_bf_db.sh ./sqlite_table_scan tests/fixtures/tiny.db
#
# Flow:
# 1. Send H, parse header, get page_size
# 2. Send R page_size 1, get page 1
# 3. Parse sqlite_schema, find table rootpage
# 4. Request that page, traverse B-tree
# 5. Decode leaf cells, output rows (e.g. CSV)
#
# Placeholder - full implementation in sqlite_table_scan.bf
