#!/usr/bin/env python3
"""
Synthetic data generator for the dbt_retail_lakehouse learning project.

Generates realistic raw retail/e-commerce datasets as CSV files under ../data/.
These CSVs represent the "raw" landing data you load into your Databricks
Unity Catalog schema (see setup/01_setup_databricks.sql) and reference from
dbt via sources (models/staging/_sources.yml).

Design goals for teaching:
  - raw_orders + raw_inventory_events carry an "updated_at" so you can demo
    INCREMENTAL models.
  - raw_products carries a "price" and "updated_at" so you can demo SNAPSHOTS
    (SCD Type 2) when prices change.
  - Deliberate light "dirtiness" (mixed case, whitespace, a few nulls) so the
    STAGING layer has real cleaning work to do and TESTS have something to catch.

Pure standard library — no pandas/numpy required.

Usage:
    python3 scripts/generate_data.py            # default sizes
    python3 scripts/generate_data.py --scale 5  # 5x more rows
"""
from __future__ import annotations

import argparse
import csv
import os
import random
from datetime import datetime, timedelta

# --------------------------------------------------------------------------- #
# Configuration
# --------------------------------------------------------------------------- #
SEED = 42
DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data")

# Base row counts (multiplied by --scale)
N_CUSTOMERS = 500
N_PRODUCTS = 120
N_STORES = 12
N_ORDERS = 4000
N_INVENTORY_EVENTS = 8000

START_DATE = datetime(2024, 1, 1)
END_DATE = datetime(2024, 12, 31)

COUNTRIES = ["IE", "GB", "US", "DE", "FR", "ES", "NL"]
CATEGORIES = ["Menswear", "Womenswear", "Kids", "Home", "Beauty", "Accessories"]
PAYMENT_METHODS = ["credit_card", "debit_card", "paypal", "gift_card", "apple_pay"]
ORDER_STATUSES = ["placed", "shipped", "completed", "returned", "cancelled"]
INVENTORY_EVENT_TYPES = ["receive", "sale", "return", "adjustment", "shrinkage"]

FIRST_NAMES = ["Aoife", "Liam", "Emma", "Noah", "Olivia", "James", "Sophia",
               "Conor", "Mia", "Sean", "Isla", "Jack", "Grace", "Daniel",
               "Ella", "Adam", "Chloe", "Ryan", "Hannah", "Luke"]
LAST_NAMES = ["Murphy", "Kelly", "Smith", "Walsh", "Brien", "Ryan", "Byrne",
              "Doyle", "Nolan", "Reilly", "Lynch", "Quinn", "Moore", "McCarthy"]


def daterange_random(rng: random.Random, start: datetime, end: datetime) -> datetime:
    delta = end - start
    seconds = rng.randint(0, int(delta.total_seconds()))
    return start + timedelta(seconds=seconds)


def maybe_dirty(rng: random.Random, value: str, p: float = 0.05) -> str:
    """Occasionally introduce whitespace / case issues for the staging layer to clean."""
    if rng.random() < p:
        choice = rng.random()
        if choice < 0.34:
            return f"  {value} "
        elif choice < 0.67:
            return value.upper()
        else:
            return value.lower()
    return value


def write_csv(name: str, header: list[str], rows: list[list]) -> None:
    os.makedirs(DATA_DIR, exist_ok=True)
    path = os.path.join(DATA_DIR, name)
    with open(path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(rows)
    print(f"  wrote {len(rows):>6} rows -> data/{name}")


def main(scale: int) -> None:
    rng = random.Random(SEED)

    n_customers = N_CUSTOMERS * scale
    n_products = N_PRODUCTS  # keep product catalog stable-ish across scales
    n_stores = N_STORES
    n_orders = N_ORDERS * scale
    n_inventory = N_INVENTORY_EVENTS * scale

    print("Generating synthetic retail datasets...")

    # ---- customers -------------------------------------------------------- #
    customers = []
    for cid in range(1, n_customers + 1):
        fn = rng.choice(FIRST_NAMES)
        ln = rng.choice(LAST_NAMES)
        email = f"{fn.lower()}.{ln.lower()}{cid}@example.com"
        signup = daterange_random(rng, START_DATE - timedelta(days=365), END_DATE)
        country = rng.choice(COUNTRIES)
        # ~2% missing email to exercise not_null tests / cleaning
        if rng.random() < 0.02:
            email = ""
        customers.append([
            cid,
            maybe_dirty(rng, fn),
            maybe_dirty(rng, ln),
            email,
            country,
            signup.strftime("%Y-%m-%d %H:%M:%S"),
        ])
    write_csv("raw_customers.csv",
              ["customer_id", "first_name", "last_name", "email", "country_code", "signup_at"],
              customers)

    # ---- products (with price + updated_at for snapshots) ----------------- #
    products = []
    for pid in range(1, n_products + 1):
        cat = rng.choice(CATEGORIES)
        price = round(rng.uniform(3.0, 120.0), 2)
        updated = daterange_random(rng, START_DATE, END_DATE)
        products.append([
            pid,
            f"{cat[:3].upper()}-{pid:04d}",           # sku
            maybe_dirty(rng, f"{cat} item {pid}"),    # product_name
            cat,
            price,
            updated.strftime("%Y-%m-%d %H:%M:%S"),
        ])
    write_csv("raw_products.csv",
              ["product_id", "sku", "product_name", "category", "price", "updated_at"],
              products)

    # ---- stores ----------------------------------------------------------- #
    stores = []
    for sid in range(1, n_stores + 1):
        country = rng.choice(COUNTRIES)
        stores.append([
            sid,
            f"Store {sid:03d}",
            country,
            rng.choice(["flagship", "standard", "outlet"]),
        ])
    write_csv("raw_stores.csv",
              ["store_id", "store_name", "country_code", "store_type"],
              stores)

    # ---- orders + order_items + payments ---------------------------------- #
    orders = []
    order_items = []
    payments = []
    item_id = 0
    for oid in range(1, n_orders + 1):
        cid = rng.randint(1, n_customers)
        sid = rng.randint(1, n_stores)
        ordered_at = daterange_random(rng, START_DATE, END_DATE)
        # updated_at >= ordered_at so incremental logic has a watermark column
        updated_at = ordered_at + timedelta(hours=rng.randint(0, 240))
        status = rng.choices(ORDER_STATUSES, weights=[10, 15, 55, 10, 10])[0]
        orders.append([
            oid, cid, sid,
            ordered_at.strftime("%Y-%m-%d %H:%M:%S"),
            updated_at.strftime("%Y-%m-%d %H:%M:%S"),
            status,
        ])

        # 1-5 line items per order
        n_lines = rng.randint(1, 5)
        order_total = 0.0
        for _ in range(n_lines):
            item_id += 1
            pid = rng.randint(1, n_products)
            qty = rng.randint(1, 4)
            unit_price = round(rng.uniform(3.0, 120.0), 2)
            line_total = round(qty * unit_price, 2)
            order_total += line_total
            order_items.append([item_id, oid, pid, qty, unit_price, line_total])

        # payments: usually one, sometimes split into two
        n_pay = 1 if rng.random() < 0.85 else 2
        remaining = round(order_total, 2)
        for p in range(n_pay):
            amt = remaining if p == n_pay - 1 else round(remaining / 2, 2)
            remaining = round(remaining - amt, 2)
            payments.append([
                f"{oid}-{p+1}", oid,
                rng.choice(PAYMENT_METHODS),
                amt,
                (ordered_at + timedelta(minutes=rng.randint(0, 60))).strftime("%Y-%m-%d %H:%M:%S"),
            ])

    write_csv("raw_orders.csv",
              ["order_id", "customer_id", "store_id", "ordered_at", "updated_at", "status"],
              orders)
    write_csv("raw_order_items.csv",
              ["order_item_id", "order_id", "product_id", "quantity", "unit_price", "line_total"],
              order_items)
    write_csv("raw_payments.csv",
              ["payment_id", "order_id", "payment_method", "amount", "paid_at"],
              payments)

    # ---- inventory events (append/incremental friendly) ------------------- #
    inventory = []
    for eid in range(1, n_inventory + 1):
        sid = rng.randint(1, n_stores)
        pid = rng.randint(1, n_products)
        etype = rng.choice(INVENTORY_EVENT_TYPES)
        qty = rng.randint(1, 50)
        # sale/shrinkage reduce stock -> negative
        if etype in ("sale", "shrinkage"):
            qty = -qty
        event_at = daterange_random(rng, START_DATE, END_DATE)
        inventory.append([
            eid, sid, pid, etype, qty,
            event_at.strftime("%Y-%m-%d %H:%M:%S"),
        ])
    write_csv("raw_inventory_events.csv",
              ["event_id", "store_id", "product_id", "event_type", "quantity_change", "event_at"],
              inventory)

    print("Done. Load these into Databricks with setup/01_setup_databricks.sql "
          "(or the load helper in the README).")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate synthetic retail data.")
    parser.add_argument("--scale", type=int, default=1,
                        help="Row-count multiplier (default 1).")
    args = parser.parse_args()
    main(args.scale)
