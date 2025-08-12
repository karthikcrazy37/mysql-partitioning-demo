-- Reset
SET SESSION FOREIGN_KEY_CHECKS = 0;
DROP DATABASE IF EXISTS orders_partition_demo;
SET SESSION FOREIGN_KEY_CHECKS = 1;

-- Create DB
CREATE DATABASE orders_partition_demo;
USE orders_partition_demo;

-- Normal table
CREATE TABLE orders_normal (
  order_id   INT PRIMARY KEY,
  user_id    INT,
  amount     DECIMAL(10,2),
  created_at DATE
);

-- Partitioned table (monthly partitions for 2023)
CREATE TABLE orders_partitioned (
  order_id   INT,
  user_id    INT,
  amount     DECIMAL(10,2),
  created_at DATE,
  PRIMARY KEY (order_id, created_at)
)
PARTITION BY RANGE (TO_DAYS(created_at)) (
  PARTITION p2023_01 VALUES LESS THAN (TO_DAYS('2023-02-01')),
  PARTITION p2023_02 VALUES LESS THAN (TO_DAYS('2023-03-01')),
  PARTITION p2023_03 VALUES LESS THAN (TO_DAYS('2023-04-01')),
  PARTITION p2023_04 VALUES LESS THAN (TO_DAYS('2023-05-01')),
  PARTITION p2023_05 VALUES LESS THAN (TO_DAYS('2023-06-01')),
  PARTITION p2023_06 VALUES LESS THAN (TO_DAYS('2023-07-01')),
  PARTITION p2023_07 VALUES LESS THAN (TO_DAYS('2023-08-01')),
  PARTITION p2023_08 VALUES LESS THAN (TO_DAYS('2023-09-01')),
  PARTITION p2023_09 VALUES LESS THAN (TO_DAYS('2023-10-01')),
  PARTITION p2023_10 VALUES LESS THAN (TO_DAYS('2023-11-01')),
  PARTITION p2023_11 VALUES LESS THAN (TO_DAYS('2023-12-01')),
  PARTITION p2023_12 VALUES LESS THAN (TO_DAYS('2024-01-01')),
  PARTITION pmax     VALUES LESS THAN (MAXVALUE)
);

-- (Run python to load 1M rows into orders_normal)
-- python3 insert_1m_orders.py

-- Copy same data into partitioned table (so comparison is apples-to-apples)
INSERT INTO orders_partitioned (order_id, user_id, amount, created_at)
SELECT order_id, user_id, amount, created_at
FROM orders_normal;

-- Verify partitions exist
SHOW CREATE TABLE orders_partitioned\G
SELECT PARTITION_NAME, TABLE_ROWS
FROM information_schema.PARTITIONS
WHERE TABLE_SCHEMA = 'orders_partition_demo'
  AND TABLE_NAME   = 'orders_partitioned'
ORDER BY PARTITION_NAME;

-- Partition pruning check (should show only p2023_07 in partitions column)
EXPLAIN SELECT * FROM orders_partitioned WHERE created_at = '2023-07-01';

-- Benchmarks (use EXPLAIN ANALYZE if available; otherwise timing via NOW(6))
-- Single date
EXPLAIN ANALYZE SELECT COUNT(*) FROM orders_normal      WHERE created_at = '2023-07-01';
EXPLAIN ANALYZE SELECT COUNT(*) FROM orders_partitioned WHERE created_at = '2023-07-01';

SET @t0 = NOW(6);
SELECT COUNT(*) FROM orders_normal WHERE created_at = '2023-07-01';
SELECT ROUND(TIMESTAMPDIFF(MICROSECOND, @t0, NOW(6))/1000, 2) AS normal_ms;

SET @t1 = NOW(6);
SELECT COUNT(*) FROM orders_partitioned WHERE created_at = '2023-07-01';
SELECT ROUND(TIMESTAMPDIFF(MICROSECOND, @t1, NOW(6))/1000, 2) AS partitioned_ms;

-- Month range
EXPLAIN ANALYZE SELECT COUNT(*) FROM orders_normal
WHERE created_at BETWEEN '2023-07-01' AND '2023-07-31';

EXPLAIN ANALYZE SELECT COUNT(*) FROM orders_partitioned
WHERE created_at BETWEEN '2023-07-01' AND '2023-07-31';

SET @t2 = NOW(6);
SELECT COUNT(*) FROM orders_normal
WHERE created_at BETWEEN '2023-07-01' AND '2023-07-31';
SELECT ROUND(TIMESTAMPDIFF(MICROSECOND, @t2, NOW(6))/1000, 2) AS normal_ms;

SET @t3 = NOW(6);
SELECT COUNT(*) FROM orders_partitioned
WHERE created_at BETWEEN '2023-07-01' AND '2023-07-31';
SELECT ROUND(TIMESTAMPDIFF(MICROSECOND, @t3, NOW(6))/1000, 2) AS partitioned_ms;

-- ==============================
-- Partition maintenance 
-- ==============================

-- 1) Drop the MAXVALUE partition (pmax) so we can append a new month
ALTER TABLE orders_partitioned
DROP PARTITION pmax;

-- 2) Append one new monthly partition, then add pmax back
ALTER TABLE orders_partitioned
ADD PARTITION (
  PARTITION p2023_aug VALUES LESS THAN (TO_DAYS('2023-09-01')),
  PARTITION pmax      VALUES LESS THAN (MAXVALUE)
);

-- Generic template to add any single boundary (useful for yearly rollouts)
-- ALTER TABLE your_table
-- ADD PARTITION (
--   PARTITION <partition_name> VALUES LESS THAN (TO_DAYS('YYYY-MM-DD'))
-- );

-- Optional: drop old partitions to keep a rolling window
-- ALTER TABLE orders_partitioned DROP PARTITION p2023_01, p2023_02;
