#!/usr/bin/env bash
set -euo pipefail

# Populate lineitem_sorted from existing `lineitem` table in SingleStore.
# Run this from a host with a MySQL client that can connect to your SingleStore cluster,
# or run inside the SingleStore notebook with equivalent SQL.

# Environment variables expected:
#   S2_HOST  - SingleStore host
#   S2_USER  - user (default: root)
#   S2_PASS  - password
#   S2_DB    - database containing lineitem (default: s2_tpch_sf100_demo)

: "${S2_HOST:?Set S2_HOST first}"
: "${S2_USER:=root}"
: "${S2_DB:=s2_tpch_sf100_demo}"

# If password not set, mysql client will prompt
MYSQL_CMD=(mysql -h "$S2_HOST" -u "$S2_USER" -p"${S2_PASS:-}" "$S2_DB" -e)

# Create the target table (idempotent)
"${MYSQL_CMD[@]}" "source sql/create_lineitem_sorted.sql"

# Populate ordered by l_shipdate (this does a single insert-select ordered operation)
# This can be heavy for 600M rows; consider running in screen/tmux and ensure you have disk and time.
"${MYSQL_CMD[@]}" "INSERT INTO lineitem_sorted SELECT * FROM lineitem ORDER BY l_shipdate;"

# Verify counts
"${MYSQL_CMD[@]}" "SELECT 'orig', COUNT(*) FROM lineitem;"
"${MYSQL_CMD[@]}" "SELECT 'sorted', COUNT(*) FROM lineitem_sorted;"

# Run Q1 against the new table to compare
"${MYSQL_CMD[@]}" "SET @orig_sql = 'SELECT l_returnflag, l_linestatus, SUM(l_quantity) AS sum_qty, SUM(l_extendedprice) AS sum_base_price, SUM(l_extendedprice*(1-l_discount)) AS sum_disc_price, SUM(l_extendedprice*(1-l_discount)*(1+l_tax)) AS sum_charge, AVG(l_quantity) AS avg_qty, AVG(l_extendedprice) AS avg_price, AVG(l_discount) AS avg_disc, COUNT(*) AS count_order FROM lineitem_sorted WHERE l_shipdate <= DATE(\'1998-12-01\') - INTERVAL 90 DAY GROUP BY l_returnflag, l_linestatus ORDER BY l_returnflag, l_linestatus';"
"${MYSQL_CMD[@]}" "-- run the query with profiling/explain in the notebook or visual explain to capture segment stats"

echo 'Populate script finished. Review counts and run Visual Explain on the new table to confirm segment elimination.'
