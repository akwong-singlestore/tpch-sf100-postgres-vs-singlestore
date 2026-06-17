#!/usr/bin/env bash
set -euo pipefail

: "${PGHOST:?Set PGHOST first}"
: "${PGUSER:?Set PGUSER first}"
: "${PGPASSWORD:?Set PGPASSWORD first}"
: "${PGDATABASE:?Set PGDATABASE first}"
: "${PGSSLROOTCERT:?Set PGSSLROOTCERT first}"

PGPORT="${PGPORT:-5432}"
OUTDIR="/tmp/pg_mv_q1_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTDIR"

echo "results -> $OUTDIR"

PSQL="psql \"host=$PGHOST port=$PGPORT dbname=$PGDATABASE user=$PGUSER sslmode=verify-full sslrootcert=$PGSSLROOTCERT\" -q -X -v ON_ERROR_STOP=1"

# start vmstat collection
vmstat 1 > "$OUTDIR/vmstat.log" 2>&1 &
VMSTAT_PID=$!

# helper to time a SQL block via wall clock
time_sql() {
  local name="$1"
  local sql="$2"
  echo "-- $name" > "$OUTDIR/${name}.sql"
  echo "$sql" >> "$OUTDIR/${name}.sql"
  start=$(date +%s%3N)
  $PSQL -f "$OUTDIR/${name}.sql" > "$OUTDIR/${name}.out" 2>&1 || true
  end=$(date +%s%3N)
  elapsed=$((end-start))
  echo "$name,$elapsed" >> "$OUTDIR/timings.csv"
  echo "$name took ${elapsed} ms"
}

# Raw Q1
RAW_SQL="\
\timing on\n\
SELECT\n    l_returnflag,\n    l_linestatus,\n    SUM(l_quantity) AS sum_qty,\n    SUM(l_extendedprice) AS sum_base_price,\n    SUM(l_extendedprice * (1 - l_discount)) AS sum_disc_price,\n    SUM(l_extendedprice * (1 - l_discount) * (1 + l_tax)) AS sum_charge,\n    AVG(l_quantity) AS avg_qty,\n    AVG(l_extendedprice) AS avg_price,\n    AVG(l_discount) AS avg_disc,\n    COUNT(*) AS count_order\nFROM lineitem\nWHERE l_shipdate <= DATE '1998-12-01' - INTERVAL '90 days'\nGROUP BY l_returnflag, l_linestatus\nORDER BY l_returnflag, l_linestatus;\n"

# Create MV (this script will both create and index as in sql/create_postgres_mv_q1.sql)
MV_CREATE_SQL=$(cat <<'SQL'
DROP MATERIALIZED VIEW IF EXISTS lineitem_q1_mv;

CREATE MATERIALIZED VIEW lineitem_q1_mv AS
SELECT
    l_returnflag,
    l_linestatus,
    SUM(l_quantity) AS sum_qty,
    SUM(l_extendedprice) AS sum_base_price,
    SUM(l_extendedprice * (1 - l_discount)) AS sum_disc_price,
    SUM(l_extendedprice * (1 - l_discount) * (1 + l_tax)) AS sum_charge,
    AVG(l_quantity) AS avg_qty,
    AVG(l_extendedprice) AS avg_price,
    AVG(l_discount) AS avg_disc,
    COUNT(*) AS count_order
FROM lineitem
WHERE l_shipdate <= DATE '1998-12-01' - INTERVAL '90 days'
GROUP BY l_returnflag, l_linestatus;

CREATE INDEX IF NOT EXISTS idx_lineitem_q1_mv_ret_status
    ON lineitem_q1_mv (l_returnflag, l_linestatus);

COMMENT ON MATERIALIZED VIEW lineitem_q1_mv IS 'Q1 pre-aggregation for TPC-H SF100';
SQL
)

# MV query
MV_QUERY_SQL="SELECT * FROM lineitem_q1_mv ORDER BY l_returnflag, l_linestatus;"

# MV refresh
MV_REFRESH_SQL="REFRESH MATERIALIZED VIEW lineitem_q1_mv;"

# Run measurements
echo "name,elapsed_ms" > "$OUTDIR/timings.csv"

time_sql raw_q1 "$RAW_SQL"
time_sql create_mv "$MV_CREATE_SQL"
time_sql mv_query "$MV_QUERY_SQL"
time_sql refresh_mv "$MV_REFRESH_SQL"

# Concurrent MV read test (spawn N parallel clients)
N=${1:-4}
echo "running concurrent MV reads: $N clients"
> "$OUTDIR/concurrent_pids.txt"
for i in $(seq 1 $N); do
  ( $PSQL -c "$MV_QUERY_SQL" > "$OUTDIR/mv_query_client_${i}.out" 2>&1 ) &
  echo $! >> "$OUTDIR/concurrent_pids.txt"
done

# Wait for them and record total time (wall clock)
start=$(date +%s%3N)
while kill -0 $(cat "$OUTDIR/concurrent_pids.txt") 2>/dev/null; do
  sleep 1
  # break if none left
  if ! ps -p $(cat "$OUTDIR/concurrent_pids.txt") > /dev/null 2>&1; then
    break
  fi
  break
done
# wait for background jobs
wait || true
end=$(date +%s%3N)
elapsed=$((end-start))
echo "concurrent_mv_read,$elapsed" >> "$OUTDIR/timings.csv"

# stop vmstat
kill $VMSTAT_PID || true

echo "done. logs in $OUTDIR"
cat "$OUTDIR/timings.csv"
