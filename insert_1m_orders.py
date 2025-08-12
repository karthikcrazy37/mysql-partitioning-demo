import mysql.connector
from datetime import datetime, timedelta
import random

# DB connection
conn = mysql.connector.connect(
    host="localhost",
    port= 3307,
    user="", #your user name
    password="", # your password
    database="orders_partition_demo"
)
cursor = conn.cursor()

def random_date(start_date, end_date):
    delta = end_date - start_date
    return (start_date + timedelta(days=random.randint(0, delta.days))).strftime('%Y-%m-%d')

start_date = datetime.strptime("2023-01-01", "%Y-%m-%d")
end_date = datetime.strptime("2023-12-31", "%Y-%m-%d")

BATCH_SIZE = 50000  # safe chunk size

for start_id in range(1, 1_000_001, BATCH_SIZE):
    records = []
    for i in range(start_id, min(start_id + BATCH_SIZE, 1_000_001)):
        records.append((
            i,
            random.randint(1000, 9999),
            round(random.uniform(10.0, 5000.0), 2),
            random_date(start_date, end_date)
        ))
    cursor.executemany(
        "INSERT INTO orders_normal (order_id, user_id, amount, created_at) VALUES (%s, %s, %s, %s)",
        records
    )
    conn.commit()
    print(f"Inserted {min(start_id + BATCH_SIZE - 1, 1_000_000)} rows")

cursor.close()
conn.close()
