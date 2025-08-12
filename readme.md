# MySQL Date Partitioning – Before vs After (Demo)

This repo shows how **range partitioning by date** improves query performance when you filter by the partition key.  
It uses one normal table and one partitioned table with the exact same data, then compares query times.

---

## What’s in here

- `partitioning.sql`  
  One script you can run in **DBeaver** (or MySQL CLI) to:
  - drop & recreate the demo database
  - create both tables (`orders_normal`, `orders_partitioned`)
  - (after you load data) copy rows into the partitioned table
  - verify partitions and pruning
  - run simple benchmarks (single date & month range)
  - **partition maintenance** (ALTER PARTITION: drop `pmax`, add next month, re-add `pmax`)

- `insert_1m_orders.py`  
  Minimal Python to insert **1,000,000** rows into `orders_normal` (batched).  
  Use it once; everything else runs from SQL/DBeaver.

---

## How partitioning works:

- We partition `orders_partitioned` by `RANGE (TO_DAYS(created_at))` with **one partition per month** plus a `pmax` catch-all.
- When your query filters on `created_at`, MySQL prunes to only the relevant partition(s).  
  Less data scanned → **faster**.
- Because of MySQL’s rule, the partitioning column **must** appear in a PRIMARY/UNIQUE key, so we use:  
  ```sql
  PRIMARY KEY (order_id, created_at)

# MySQL Partitioning Performance Results

## Performance results from this demo

- **Normal table:** `0.268444` seconds  
- **Partitioned table:** `0.043798` seconds  
- **Speed improvement:** ~**6.13× faster** with partitioning


2) Run the Python loader:
```bash
pip install mysql-connector-python
python3 insert_1m_orders.py
