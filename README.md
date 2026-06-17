# TPC-H SF100 Benchmark Reproducibility

This repository contains the assets needed to reproduce a TPC-H SF100 benchmark comparison between SingleStore and PostgreSQL.

## What is included

- `s2_tpch_sf100_demo.ipynb` — SingleStore TPC-H SF100 benchmark notebook.
- `tpch_sf100_schema.sql` — PostgreSQL schema definition for TPC-H SF100.
- `tpch_q1_q4_q21.sql` — Benchmark query set for Q1, Q4, Q21 used on both systems.
- `load_tpch_sf100_to_postgres.sh` — Helper script to download public SF100 data from S3 and load into PostgreSQL.
- `sql/create_postgres_mv_q1.sql` — PostgreSQL Q1 materialized view definition.
- `scripts/run_postgres_queries.sh` — Generic PostgreSQL benchmark helper script.
- `scripts/measure_postgres_mv_q1.sh` — PostgreSQL benchmark + MV measurement script.
- `scripts/measure_singlestore_mv_q1.sh` — SingleStore benchmark + MV measurement script.

## Recommended workflow

### PostgreSQL

1. Ensure your PostgreSQL host is reachable from the machine where you run this repo.
2. Set environment variables:
   ```bash
   export PGHOST="<YOUR_POSTGRES_HOST>"
   export PGPORT="5432"
   export PGDATABASE="tpch_sf100"
   export PGUSER="<YOUR_USER>"
   export PGPASSWORD='<YOUR_PASSWORD>'
   export PGSSLROOTCERT="$HOME/global-bundle.pem"
   ```
3. Initialize your schema and load SF100 data using your existing tooling or the included `load_tpch_sf100_to_postgres.sh` script.
4. Run the benchmark helper:
   ```bash
   ./scripts/run_postgres_queries.sh
   ```
5. To capture MV timings and concurrent read behavior:
   ```bash
   ./scripts/measure_postgres_mv_q1.sh 4
   ```

### SingleStore

1. Open `s2_tpch_sf100_demo.ipynb` in SingleStore Helios or a compatible notebook environment.
2. Run the setup and pipeline cells to create the SingleStore tables and ingest the SF100 data.
3. Execute the benchmark query cells.
4. Use the included SingleStore helper if you want to measure MV build and query behavior outside the notebook.

## What to compare

For each query, capture or report:

- Execution time on SingleStore
- Execution time on PostgreSQL
- Output result counts and values
- Any differences in query plans or optimizer behavior

### Materialized Views (Optional)

**PostgreSQL**: Materialized views are snapshot-based and require periodic `REFRESH MATERIALIZED VIEW` to update.

**SingleStore**: Preview support for materialized-view style projections is available in recent releases. Unlike PostgreSQL's snapshot-based approach, SingleStore MVs are designed as continuously updated aggregates maintained incrementally at commit time. They're intended to be lean and aggregate-focused, with regular SQL views/joins layered on top if needed.

The included MV scripts demonstrate performance characteristics for Q1 aggregations on both platforms.

## Notes

- Keep credentials and sensitive connection details out of source control.
- The PostgreSQL scripts are generic and can be used with any compatible PostgreSQL host.
- **SingleStore Materialized Views**: The SingleStore MV scripts demonstrate preview functionality available in recent releases. Check with your SingleStore account team or documentation for availability in your specific version.

## Documentation references

- PostgreSQL materialized views: https://www.postgresql.org/docs/current/sql-creatematerializedview.html
- PostgreSQL refresh materialized view: https://www.postgresql.org/docs/current/sql-refreshmaterializedview.html
- PostgreSQL explain/analyze: https://www.postgresql.org/docs/current/using-explain.html
- PostgreSQL performance tuning: https://www.postgresql.org/docs/current/runtime-config-resource.html
- SingleStore materialized views: https://docs.singlestore.com/docs/current/reference/sql-reference/ddl/create-materialized-view/
- SingleStore columnstore and clustered columnstore: https://docs.singlestore.com/docs/current/reference/sql-reference/ddl/create-table/#clustered-columnstore
- SingleStore Visual Explain / query profile: https://docs.singlestore.com/docs/current/reference/sql-reference/diagnostics/visual-explain/
