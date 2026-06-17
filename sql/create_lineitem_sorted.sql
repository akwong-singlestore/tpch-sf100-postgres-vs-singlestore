-- Create a sorted test table for `lineitem` in SingleStore to enable segment elimination on `l_shipdate`.
-- Run this in SingleStore (Helios) using the notebook or a MySQL client connected to SingleStore.

CREATE TABLE IF NOT EXISTS lineitem_sorted (
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
  KEY `sort_shipdate` (`l_shipdate`) USING CLUSTERED COLUMNSTORE
);

-- Notes:
-- - The `sort_shipdate` clustered columnstore key will encourage segment layout by shipdate when data is inserted ordered by `l_shipdate`.
-- - Adjust SHARD/UNIQUE keys to match your production configuration if different.
