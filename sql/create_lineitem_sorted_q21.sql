-- Create a sorted test table for `lineitem` optimized for Q21.
-- Q21 needs: l_receiptdate > l_commitdate filter and joins on l_orderkey

CREATE TABLE IF NOT EXISTS lineitem_sorted_q21 (
  l_orderkey      BIGINT NOT NULL,
  l_partkey       INT NOT NULL,
  l_suppkey       INT NOT NULL,
  l_linenumber    INT NOT NULL,
  l_quantity      DECIMAL(15,2) NOT NULL,
  l_extendedprice DECIMAL(15,2) NOT NULL,
  l_discount      DECIMAL(15,2) NOT NULL,
  l_tax           DECIMAL(15,2) NOT NULL,
  l_returnflag    CHAR(1) NOT NULL,
  l_linestatus    CHAR(1) NOT NULL,
  l_shipdate      DATE NOT NULL,
  l_commitdate    DATE NOT NULL,
  l_receiptdate   DATE NOT NULL,
  l_shipinstruct  VARCHAR(25) NOT NULL,
  l_shipmode      VARCHAR(10) NOT NULL,
  l_comment       VARCHAR(44) NOT NULL,
  UNIQUE KEY `pk` (`l_orderkey`,`l_linenumber`) USING HASH,
  SHARD KEY `__SHARDKEY` (`l_orderkey`),
  KEY `sort_orderkey_commitdate` (`l_orderkey`, `l_commitdate`) USING CLUSTERED COLUMNSTORE
);

-- Populate from existing lineitem table, sorted by orderkey and commitdate
INSERT INTO lineitem_sorted_q21
SELECT * FROM lineitem
ORDER BY l_orderkey, l_commitdate;

-- Notes:
-- - Composite sort key on (l_orderkey, l_commitdate) helps both join and filter operations
-- - Q21 has complex EXISTS/NOT EXISTS with l_receiptdate > l_commitdate predicate
