-- Create a sorted test table for `orders` in SingleStore to enable segment elimination on `o_orderdate`.
-- This optimizes Q4 which filters on o_orderdate.

CREATE TABLE IF NOT EXISTS orders_sorted (
  o_orderkey      BIGINT NOT NULL,
  o_custkey       INT NOT NULL,
  o_orderstatus   CHAR(1) NOT NULL,
  o_totalprice    DECIMAL(15,2) NOT NULL,
  o_orderdate     DATE NOT NULL,
  o_orderpriority VARCHAR(15) NOT NULL,
  o_clerk         VARCHAR(15) NOT NULL,
  o_shippriority  INT NOT NULL,
  o_comment       VARCHAR(79) NOT NULL,
  UNIQUE KEY `pk` (`o_orderkey`) USING HASH,
  SHARD KEY `__SHARDKEY` (`o_orderkey`),
  KEY `sort_orderdate` (`o_orderdate`) USING CLUSTERED COLUMNSTORE
);

-- Populate from existing orders table, sorted by o_orderdate
INSERT INTO orders_sorted
SELECT * FROM orders
ORDER BY o_orderdate;

-- Notes:
-- - The `sort_orderdate` clustered columnstore key enables segment elimination for date range filters
-- - Q4 filters: o_orderdate >= '1993-07-01' AND o_orderdate < '1993-10-01'
