from __future__ import annotations

import uuid
from datetime import date

from sqlalchemy import Select, func, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql import select

from app.models.pricing_record import PricingRecord


class PricingRepository:
    async def get_by_id(self, db: AsyncSession, record_id: uuid.UUID) -> PricingRecord | None:
        res = await db.execute(select(PricingRecord).where(PricingRecord.id == record_id))
        return res.scalar_one_or_none()

    async def bulk_insert(self, db: AsyncSession, rows: list[dict]) -> None:
        if not rows:
            return
        stmt = insert(PricingRecord).values(rows)
        await db.execute(stmt)

    async def bulk_upsert_by_store_sku_date(self, db: AsyncSession, rows: list[dict]) -> list[dict]:
        if not rows:
            return []
        stmt = insert(PricingRecord).values(rows)
        stmt = stmt.on_conflict_do_update(
            index_elements=[PricingRecord.country_code, PricingRecord.store_id, PricingRecord.sku, PricingRecord.date],
            set_={
                "product_name": stmt.excluded.product_name,
                "price": stmt.excluded.price,
                "currency_code": stmt.excluded.currency_code,
                "tax_inclusive": stmt.excluded.tax_inclusive,
                "observed_at": func.now(),
                "feed_id": stmt.excluded.feed_id,
                "source_line": stmt.excluded.source_line,
                "updated_by_user_id": stmt.excluded.updated_by_user_id,
                "updated_source": stmt.excluded.updated_source,
                "update_reason": stmt.excluded.update_reason,
                "updated_at": func.now(),
            },
        )
        stmt = stmt.returning(
            PricingRecord.id,
            PricingRecord.country_code,
            PricingRecord.store_id,
            PricingRecord.sku,
            PricingRecord.product_name,
            PricingRecord.price,
            PricingRecord.currency_code,
            PricingRecord.tax_inclusive,
            PricingRecord.date,
        )
        res = await db.execute(stmt)
        out: list[dict] = []
        for row in res.mappings().all():
            out.append(
                {
                    "id": row["id"],
                    "country_code": row["country_code"],
                    "store_id": row["store_id"],
                    "sku": row["sku"],
                    "product_name": row["product_name"],
                    "price": float(row["price"]),
                    "date": row["date"],
                    "currency_code": row["currency_code"],
                    "tax_inclusive": row["tax_inclusive"],
                }
            )
        return out

    async def update_price(self, db: AsyncSession, record_id: uuid.UUID, price: float) -> PricingRecord | None:
        stmt = (
            update(PricingRecord)
            .where(PricingRecord.id == record_id)
            .values(price=price)
            .returning(PricingRecord)
        )
        res = await db.execute(stmt)
        return res.scalar_one_or_none()

    async def update_fields(self, db: AsyncSession, record_id: uuid.UUID, fields: dict) -> PricingRecord | None:
        if not fields:
            return await self.get_by_id(db, record_id)
        stmt = (
            update(PricingRecord)
            .where(PricingRecord.id == record_id)
            .values(**fields)
            .returning(PricingRecord)
        )
        res = await db.execute(stmt)
        return res.scalar_one_or_none()

    async def get_by_ids(self, db: AsyncSession, record_ids: list[uuid.UUID]) -> list[PricingRecord]:
        if not record_ids:
            return []
        res = await db.execute(select(PricingRecord).where(PricingRecord.id.in_(record_ids)))
        rows = list(res.scalars().all())
        by_id = {r.id: r for r in rows}
        return [by_id[rid] for rid in record_ids if rid in by_id]

    def db_fallback_search_stmt(
        self,
        *,
        q: str | None,
        country_code: str | None,
        store_ids: list[str] | None,
        skus: list[str] | None,
        date_from: date | None,
        date_to: date | None,
    ) -> Select:
        stmt: Select = select(PricingRecord)
        if country_code:
            stmt = stmt.where(PricingRecord.country_code == country_code)
        if store_ids:
            stmt = stmt.where(PricingRecord.store_id.in_(store_ids))
        if skus:
            stmt = stmt.where(PricingRecord.sku.in_(skus))
        if date_from:
            stmt = stmt.where(PricingRecord.date >= date_from)
        if date_to:
            stmt = stmt.where(PricingRecord.date <= date_to)
        if q:
            stmt = stmt.where(PricingRecord.product_name.ilike(f"%{q}%"))
        return stmt.order_by(PricingRecord.date.desc())

