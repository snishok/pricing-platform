from __future__ import annotations

from datetime import date

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncConnection


async def ensure_monthly_partitions(
    conn: AsyncConnection,
    *,
    table_name: str,
    partition_column: str,
    start_month: date,
    months_backfill: int,
    months_ahead: int,
) -> None:
    """
    Create RANGE (monthly) partitions for a table that is already partitioned.
    This function is idempotent and safe to run on startup.
    """
    await conn.execute(
        text(
            """
            DO $$
            DECLARE
              m date;
              m_start date := :start_month::date;
              backfill int := :months_backfill;
              ahead int := :months_ahead;
              tbl text := :table_name;
              col text := :partition_column;
              part_name text;
              from_d date;
              to_d date;
            BEGIN
              FOR i IN -backfill..ahead LOOP
                m := (date_trunc('month', m_start)::date + make_interval(months => i))::date;
                from_d := m;
                to_d := (m + make_interval(months => 1))::date;
                part_name := format('%s_p_%s', tbl, to_char(m, 'YYYYMM'));

                EXECUTE format(
                  'CREATE TABLE IF NOT EXISTS %I PARTITION OF %I FOR VALUES FROM (%L) TO (%L)',
                  part_name, tbl, from_d, to_d
                );

                -- Add lightweight local indexes to partitions
                EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON %I (%I)', part_name || '_date', part_name, col);
              END LOOP;
            END $$;
            """
        ),
        {
            "start_month": start_month.isoformat(),
            "months_backfill": months_backfill,
            "months_ahead": months_ahead,
            "table_name": table_name,
            "partition_column": partition_column,
        },
    )


async def is_partitioned(conn: AsyncConnection, *, table_name: str) -> bool:
    res = await conn.execute(
        text(
            """
            SELECT EXISTS(
              SELECT 1
              FROM pg_partitioned_table p
              JOIN pg_class c ON c.oid = p.partrelid
              WHERE c.relname = :table_name
            ) AS is_partitioned
            """
        ),
        {"table_name": table_name},
    )
    return bool(res.scalar_one())


async def convert_pricing_records_to_partitioned(conn: AsyncConnection) -> None:
    """
    One-time conversion of pricing_records into a RANGE-partitioned table by 'date'.
    Keeps name 'pricing_records' by swapping tables.

    Notes:
    - Intended for small/medium datasets (demo/prototype). For large datasets, do this via an offline migration.
    - Uses exclusive table locks while copying.
    """
    if await is_partitioned(conn, table_name="pricing_records"):
        return

    await conn.execute(text("LOCK TABLE pricing_records IN ACCESS EXCLUSIVE MODE"))

    await conn.execute(
        text(
            """
            DROP TABLE IF EXISTS pricing_records_new CASCADE;
            CREATE TABLE pricing_records_new (
              LIKE pricing_records INCLUDING DEFAULTS INCLUDING CONSTRAINTS INCLUDING INDEXES
            ) PARTITION BY RANGE (date);
            """
        )
    )

    # Copy data
    await conn.execute(text("INSERT INTO pricing_records_new SELECT * FROM pricing_records"))

    # Swap
    await conn.execute(text("ALTER TABLE pricing_records RENAME TO pricing_records_unpartitioned_backup"))
    await conn.execute(text("ALTER TABLE pricing_records_new RENAME TO pricing_records"))

    # Recreate parent-level unique index/constraint for ON CONFLICT to target
    await conn.execute(
        text(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS uq_pricing_records_country_store_sku_date_idx
            ON pricing_records (country_code, store_id, sku, date)
            """
        )
    )
