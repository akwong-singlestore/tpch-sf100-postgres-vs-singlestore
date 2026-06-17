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
\i tpch_q1_q4_q21.sql
EOSQL
