-- Create and refresh a PostgreSQL materialized view for the TPC-H Q1 aggregation.
-- Run this from a host that can connect to the PostgreSQL instance.

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
