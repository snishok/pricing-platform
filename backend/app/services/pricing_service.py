from __future__ import annotations

import uuid
from datetime import date
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.pricing_record import PricingRecord
from app.models.pricing_record_audit import PricingRecordAudit
from app.repositories.pricing_repository import PricingRepository
from app.services.typesense_service import TypesenseService


REQUIRED_CSV_COLUMNS = {"store_id", "sku", "product_name", "price", "date"}
_DETAIL_RECORD_NOT_FOUND = "Record not found"


class PricingService:
    def __init__(self, repo: PricingRepository | None = None) -> None:
        self._repo = repo or PricingRepository()

    async def get_by_id(self, db: AsyncSession, record_id: uuid.UUID) -> PricingRecord:
        rec = await self._repo.get_by_id(db, record_id)
        if not rec:
            raise LookupError(_DETAIL_RECORD_NOT_FOUND)
        return rec

    async def get_by_ids(self, db: AsyncSession, record_ids: list[uuid.UUID]) -> list[PricingRecord]:
        return await self._repo.get_by_ids(db, record_ids)

    async def update_price(
        self,
        db: AsyncSession,
        *,
        record_id: uuid.UUID,
        price: float,
        typesense: TypesenseService,
    ) -> PricingRecord:
        rec = await self._repo.update_price(db, record_id, price)
        if not rec:
            raise LookupError(_DETAIL_RECORD_NOT_FOUND)
        await db.commit()
        await typesense.update_price(record_id=str(rec.id), price=float(rec.price))
        return rec

    async def update_record(
        self,
        db: AsyncSession,
        *,
        record_id: uuid.UUID,
        user_id: uuid.UUID,
        fields: dict[str, Any],
        typesense: TypesenseService,
    ) -> PricingRecord:
        existing = await self._repo.get_by_id(db, record_id)
        if not existing:
            raise LookupError(_DETAIL_RECORD_NOT_FOUND)

        old_values = {
            "country_code": existing.country_code,
            "store_id": existing.store_id,
            "sku": existing.sku,
            "product_name": existing.product_name,
            "price": float(existing.price),
            "currency_code": existing.currency_code,
            "tax_inclusive": existing.tax_inclusive,
            "date": existing.date.isoformat(),
        }

        update_reason = None
        if "update_reason" in fields:
            update_reason = fields.pop("update_reason")

        fields["updated_by_user_id"] = user_id
        fields["updated_source"] = "manual"
        fields["update_reason"] = update_reason

        rec = await self._repo.update_fields(db, record_id, fields)
        if not rec:
            raise LookupError(_DETAIL_RECORD_NOT_FOUND)

        new_values = {
            "country_code": rec.country_code,
            "store_id": rec.store_id,
            "sku": rec.sku,
            "product_name": rec.product_name,
            "price": float(rec.price),
            "currency_code": rec.currency_code,
            "tax_inclusive": rec.tax_inclusive,
            "date": rec.date.isoformat(),
        }

        db.add(
            PricingRecordAudit(
                record_id=rec.id,
                user_id=user_id,
                feed_id=None,
                source="manual",
                reason=update_reason,
                old_values=old_values,
                new_values=new_values,
            )
        )
        await db.commit()

        await typesense.update_pricing_record(
            record_id=str(rec.id),
            fields={
                "country_code": rec.country_code,
                "store_id": rec.store_id,
                "sku": rec.sku,
                "product_name": rec.product_name,
                "price": float(rec.price),
                "currency_code": rec.currency_code,
                "tax_inclusive": rec.tax_inclusive,
                "date": rec.date,
            },
        )

        return rec

    async def db_fallback_search(
        self,
        db: AsyncSession,
        *,
        q: str | None,
        country_code: str | None,
        store_ids: list[str] | None,
        skus: list[str] | None,
        date_from: date | None,
        date_to: date | None,
        page: int,
        per_page: int,
    ) -> tuple[list[PricingRecord], int]:
        base = self._repo.db_fallback_search_stmt(
            q=q, country_code=country_code, store_ids=store_ids, skus=skus, date_from=date_from, date_to=date_to
        )
        count_stmt = select(func.count()).select_from(base.subquery())
        total = int((await db.execute(count_stmt)).scalar_one())

        stmt = base.offset((page - 1) * per_page).limit(per_page)
        rows = (await db.execute(stmt)).scalars().all()
        return list(rows), total

    def validate_csv_columns(self, cols: set[str]) -> None:
        missing = REQUIRED_CSV_COLUMNS - cols
        if missing:
            raise ValueError(f"Missing columns: {', '.join(sorted(missing))}")

    async def persist_and_index_chunk(
        self,
        db: AsyncSession,
        *,
        chunk_rows: list[dict[str, Any]],
        typesense: TypesenseService,
    ) -> int:
        canonical = await self._repo.bulk_upsert_by_store_sku_date(db, chunk_rows)
        await db.commit()
        await typesense.upsert_pricing_records(canonical)
        return len(canonical)

