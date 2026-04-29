from __future__ import annotations

import argparse
import asyncio
import random
import uuid
from dataclasses import dataclass
from datetime import date

from app.core.config import settings
from app.core.logging import configure_logging, logger
from app.core.typesense_client import get_typesense_client
from app.core.typesense_client import ensure_pricing_collection
from app.core.db import SessionLocal
from app.services.pricing_service import PricingService
from app.services.typesense_service import TypesenseService


@dataclass(frozen=True)
class SeedArgs:
    products: int
    store_count: int
    seed: int
    chunk_size: int
    business_date: date


def _parse_args() -> SeedArgs:
    p = argparse.ArgumentParser(description="Seed demo data into Postgres + Typesense.")
    p.add_argument("--products", type=int, default=10_000, help="Number of product rows to generate (default: 10000).")
    p.add_argument("--store-count", type=int, default=25, help="Number of store_ids to spread data across (default: 25).")
    p.add_argument("--seed", type=int, default=1337, help="Deterministic RNG seed for reproducible datasets.")
    # Postgres (asyncpg) hard-limits bind parameters to 32767. Keep a safe default.
    p.add_argument("--chunk-size", type=int, default=2_000, help="Rows per DB/typesense upsert batch (default: 2000).")
    p.add_argument(
        "--date",
        dest="business_date",
        type=date.fromisoformat,
        default=date.today(),
        help="Business date for seeded rows, format YYYY-MM-DD (default: today).",
    )
    ns = p.parse_args()

    products = max(0, int(ns.products))
    store_count = max(1, int(ns.store_count))
    chunk_size = max(1, int(ns.chunk_size))
    return SeedArgs(
        products=products,
        store_count=store_count,
        seed=int(ns.seed),
        chunk_size=chunk_size,
        business_date=ns.business_date,
    )


def _build_rows(*, args: SeedArgs, start_idx: int, count: int, rng: random.Random) -> list[dict]:
    rows: list[dict] = []
    for i in range(start_idx, start_idx + count):
        store_id = f"S{(i % args.store_count) + 1:04d}"
        sku = f"SKU-{i:08d}"
        product_name = f"Demo Product {i:08d}"
        price = round(rng.uniform(10, 9999), 2)
        rows.append(
            {
                "id": uuid.uuid4(),
                "country_code": settings.default_country_code,
                "store_id": store_id,
                "sku": sku,
                "product_name": product_name,
                "price": price,
                "currency_code": settings.default_currency_code,
                "tax_inclusive": True,
                "date": args.business_date,
                "feed_id": None,
                "source_line": None,
                "updated_by_user_id": None,
                "updated_source": "ingest",
                "update_reason": None,
            }
        )
    return rows


async def _run(args: SeedArgs) -> None:
    rng = random.Random(args.seed)

    client = get_typesense_client()
    await ensure_pricing_collection(client)
    typesense = TypesenseService(client)
    svc = PricingService()

    total = args.products
    if total <= 0:
        logger.info("seed_demo_data.noop", products=0)
        return

    logger.info(
        "seed_demo_data.start",
        products=total,
        store_count=args.store_count,
        chunk_size=args.chunk_size,
        date=args.business_date.isoformat(),
    )

    inserted = 0
    async with SessionLocal() as db:
        offset = 0
        while offset < total:
            batch = min(args.chunk_size, total - offset)
            rows = _build_rows(args=args, start_idx=offset + 1, count=batch, rng=rng)
            await svc.persist_and_index_chunk(db, chunk_rows=rows, typesense=typesense)
            inserted += batch
            offset += batch
            logger.info("seed_demo_data.progress", inserted=inserted, total=total)

    logger.info("seed_demo_data.done", inserted=inserted, total=total)


def main() -> None:
    configure_logging(settings.environment)
    args = _parse_args()
    asyncio.run(_run(args))


if __name__ == "__main__":
    main()

