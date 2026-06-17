#!/usr/bin/env bash
set -euo pipefail

: "${S2_HOST:?Set S2_HOST first}"
: "${S2_USER:?Set S2_USER first}"
: "${S2_PASS:?Set S2_PASS first}"
: "${S2_DB:?Set S2_DB first}"

OUTDIR="/tmp/s2_mv_q1_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTDIR"

echo "results -> $OUTDIR"

MYSQL_CMD=(mysql -h "$S2_HOST" -u "$S2_USER" -p"$S2_PASS" "$S2_DB" -e)

# start vmstat
vmstat 1 > "$OUTDIR/vmstat.log" 2>&1 &
VMSTAT_PID=$!

start_ms() { date +%s%3N; }

run_mysql_block() {
  local name="$1"
  local sql="$2"
  echo "$sql" > "$OUTDIR/${name}.sql"
  start=$(start_ms)
  "${MYSQL_CMD[@]}" "$sql" > "$OUTDIR/${name}.out" 2>&1 || true
  end=$(date +%s%3N)
  elapsed=$((end-start))
  echo "$name,$elapsed" >> "$OUTDIR/timings.csv"
  echo "$name took ${elapsed} ms"
}

RAW_SQL="SELECT l_returnflag, l_linestatus, SUM(l_quantity) AS sum_qty, SUM(l_extendedprice) AS sum_base_price, SUM(l_extendedprice * (1 - l_discount)) AS sum_disc_price, SUM(l_extendedprice * (1 - l_discount) * (1 + l_tax)) AS sum_charge, AVG(l_quantity) AS avg_qty, AVG(l_extendedprice) AS avg_price, AVG(l_discount) AS avg_disc, COUNT(*) AS count_order FROM lineitem WHERE l_shipdate <= DATE('1998-12-01') - INTERVAL 90 DAY GROUP BY l_returnflag, l_linestatus ORDER BY l_returnflag, l_linestatus;"

MV_NAME="lineitem_q1_mv_fullbuild"
MV_CREATE_SQL="DROP MATERIALIZED VIEW IF EXISTS ${MV_NAME}; CREATE MATERIALIZED VIEW ${MV_NAME} AS SELECT l_returnflag, l_linestatus, SUM(l_quantity) AS sum_qty, SUM(l_extendedprice) AS sum_base_price, SUM(l_extendedprice * (1 - l_discount)) AS sum_disc_price, SUM(l_extendedprice * (1 - l_discount) * (1 + l_tax)) AS sum_charge, AVG(l_quantity) AS avg_qty, AVG(l_extendedprice) AS avg_price, AVG(l_discount) AS avg_disc, COUNT(*) AS count_order FROM lineitem GROUP BY l_returnflag, l_linestatus;"

MV_QUERY_SQL="SELECT * FROM ${MV_NAME} ORDER BY l_returnflag, l_linestatus;"

# Run
echo "name,elapsed_ms" > "$OUTDIR/timings.csv"

run_mysql_block raw_q1 "$RAW_SQL"
run_mysql_block create_mv_fullbuild "$MV_CREATE_SQL"
run_mysql_block mv_query_fullbuild "$MV_QUERY_SQL"
run_mysql_block refresh_mv_fullbuild "REFRESH MATERIALIZED VIEW ${MV_NAME};"

# concurrent read test
N=${1:-4}
echo "running concurrent MV reads: $N clients"
> "$OUTDIR/concurrent_pids.txt"
for i in $(seq 1 $N); do
  ( "${MYSQL_CMD[@]}" "$MV_QUERY_SQL" > "$OUTDIR/mv_query_client_${i}.out" 2>&1 ) &
  echo $! >> "$OUTDIR/concurrent_pids.txt"
done

wait || true

echo "stopping vmstat"
kill $VMSTAT_PID || true

cat "$OUTDIR/timings.csv"

echo "done. logs in $OUTDIR"
