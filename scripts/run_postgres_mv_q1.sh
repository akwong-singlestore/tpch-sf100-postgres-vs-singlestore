#!/usr/bin/env bash
set -euo pipefail

: "${PGHOST:?Set PGHOST first}"
: "${PGUSER:?Set PGUSER first}"
: "${PGPASSWORD:?Set PGPASSWORD first}"
: "${PGDATABASE:?Set PGDATABASE first}"
: "${PGSSLROOTCERT:?Set PGSSLROOTCERT first}"

PGPORT="${PGPORT:-5432}"

psql "host=$PGHOST port=$PGPORT dbname=$PGDATABASE user=$PGUSER sslmode=verify-full sslrootcert=$PGSSLROOTCERT" <<'EOSQL'
\timing on

-- Raw Q1 baseline
SELECT 'raw_q1' AS stage;
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
GROUP BY l_returnflag, l_linestatus
ORDER BY l_returnflag, l_linestatus;

-- Create/refresh the MV
\i sql/create_postgres_mv_q1.sql

-- MV query
SELECT 'mv_q1' AS stage;
SELECT *
FROM lineitem_q1_mv
ORDER BY l_returnflag, l_linestatus;

-- Refresh timing
SELECT 'refresh_mv' AS stage;
REFRESH MATERIALIZED VIEW lineitem_q1_mv;
EOSQL
