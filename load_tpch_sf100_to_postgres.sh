#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   export PGHOST="<YOUR_POSTGRES_HOST>"
#   export PGPORT="5432"
#   export PGDATABASE="tpch_sf100"
#   export PGUSER="<YOUR_USER>"
#   export PGPASSWORD='<YOUR_PASSWORD>'
#   export PGSSLROOTCERT="$HOME/global-bundle.pem"
#   bash load_tpch_sf100_to_postgres.sh

: "${PGHOST:?Set PGHOST first}"
: "${PGUSER:?Set PGUSER first}"
: "${PGPASSWORD:?Set PGPASSWORD first}"
: "${PGDATABASE:?Set PGDATABASE first}"
: "${PGSSLROOTCERT:?Set PGSSLROOTCERT first}"

PGPORT="${PGPORT:-5432}"
ROOT="$HOME/tpch_sf100"
mkdir -p "$ROOT"/{region,nation,supplier,customer,part,partsupp,orders,lineitem}

PGURL="host=$PGHOST port=$PGPORT dbname=$PGDATABASE user=$PGUSER sslmode=verify-full sslrootcert=$PGSSLROOTCERT"

sync_prefix() {
  local tbl="$1"
  echo "==> Syncing $tbl from public S3"
  aws s3 sync --no-sign-request "s3://memsql-tpch-dataset/sf_100/$tbl/" "$ROOT/$tbl/"
}

load_table() {
  local tbl="$1"
  echo "==> Loading $tbl"
  if find "$ROOT/$tbl" -type f | grep -q .gz; then
    find "$ROOT/$tbl" -type f | sort | while read -r f; do gzip -dc "$f"; done \
      | sed 's/|$//' \
      | psql "$PGURL" -c "\\copy $tbl FROM STDIN WITH (FORMAT csv, DELIMITER '|')"
  else
    find "$ROOT/$tbl" -type f | sort | while read -r f; do cat "$f"; done \
      | sed 's/|$//' \
      | psql "$PGURL" -c "\\copy $tbl FROM STDIN WITH (FORMAT csv, DELIMITER '|')"
  fi
}

for t in region nation supplier customer part partsupp orders lineitem; do
  sync_prefix "$t"
done

for t in region nation supplier customer part partsupp orders lineitem; do
  load_table "$t"
done

echo "==> Running ANALYZE"
psql "$PGURL" -c "ANALYZE;"

echo "==> Validating row counts"
psql "$PGURL" -c "
SELECT 'customer' AS table_name, COUNT(*) AS row_count FROM customer
UNION ALL
SELECT 'lineitem', COUNT(*) FROM lineitem
UNION ALL
SELECT 'nation', COUNT(*) FROM nation
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'part', COUNT(*) FROM part
UNION ALL
SELECT 'partsupp', COUNT(*) FROM partsupp
UNION ALL
SELECT 'region', COUNT(*) FROM region
UNION ALL
SELECT 'supplier', COUNT(*) FROM supplier
ORDER BY table_name;"

echo "==> Done. Next: run your benchmark query file"
echo "psql \"$PGURL\" -f $HOME/tpch_q1_q4_q21.sql"
