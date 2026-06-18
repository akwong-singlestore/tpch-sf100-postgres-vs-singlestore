-- TPC-H SF100 Optimized Queries with Sort Keys
-- Run these after creating the sorted tables
-- Use for SingleStore only (sort keys are SingleStore-native)

-- ============================================
-- Q1: Pricing Summary Report (SORTED)
-- Uses: lineitem_sorted with sort key on l_shipdate
-- ============================================

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
FROM lineitem_sorted
WHERE l_shipdate <= DATE('1998-12-01') - INTERVAL '90' DAY
GROUP BY l_returnflag, l_linestatus
ORDER BY l_returnflag, l_linestatus;

-- ============================================
-- Q4: Order Priority Check (SORTED)
-- Uses: orders_sorted with sort key on o_orderdate
-- ============================================

SELECT
    o_orderpriority,
    COUNT(*) AS order_count
FROM orders_sorted
WHERE o_orderdate >= DATE('1993-07-01')
  AND o_orderdate < DATE('1993-10-01')
  AND EXISTS (
      SELECT *
      FROM lineitem
      WHERE l_orderkey = o_orderkey
        AND l_commitdate < l_receiptdate
  )
GROUP BY o_orderpriority
ORDER BY o_orderpriority;

-- ============================================
-- Q21: Supplier Wait Analysis (SORTED)
-- Uses: lineitem_sorted_q21 with sort key on (l_orderkey, l_commitdate)
-- ============================================

SELECT
    s_name,
    COUNT(*) AS numwait
FROM supplier,
     lineitem_sorted_q21 l1,
     orders,
     nation
WHERE s_suppkey = l1.l_suppkey
  AND o_orderkey = l1.l_orderkey
  AND o_orderstatus = 'F'
  AND l1.l_receiptdate > l1.l_commitdate
  AND EXISTS (
      SELECT *
      FROM lineitem_sorted_q21 l2
      WHERE l2.l_orderkey = l1.l_orderkey
        AND l2.l_suppkey <> l1.l_suppkey
  )
  AND NOT EXISTS (
      SELECT *
      FROM lineitem_sorted_q21 l3
      WHERE l3.l_orderkey = l1.l_orderkey
        AND l3.l_suppkey <> l1.l_suppkey
        AND l3.l_receiptdate > l3.l_commitdate
  )
  AND s_nationkey = n_nationkey
  AND n_name = 'EGYPT'
GROUP BY s_name
ORDER BY numwait DESC, s_name
LIMIT 100;
