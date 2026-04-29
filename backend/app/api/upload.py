from __future__ import annotations

import asyncio
import hashlib
import io
import uuid
from datetime import date

import pandas as pd
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import UploadActor, get_db, require_upload_actor
from app.core.config import settings
from app.core.logging import logger
from app.core.typesense_client import get_typesense_client
from app.models.pricing_feed_upload import PricingFeedUpload
from app.services.pricing_search_cache import clear_pricing_search_caches
from app.services.pricing_service import PricingService
from app.services.typesense_service import TypesenseService


router = APIRouter(tags=["upload"])


def _read_and_prepare_chunk(chunks, svc: PricingService) -> tuple[list[dict], int] | None:
    try:
        chunk = next(chunks)
    except StopIteration:
        return None

    svc.validate_csv_columns(set(chunk.columns))

    chunk = chunk.copy()
    chunk["date"] = pd.to_datetime(chunk["date"], errors="raise").dt.date
    chunk["price"] = pd.to_numeric(chunk["price"], errors="raise")
    return chunk.to_dict(orient="records"), len(chunk)


@router.post("/upload-csv")
async def upload_csv(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    actor: UploadActor = Depends(require_upload_actor),
) -> dict[str, int]:
    if not file.filename or not file.filename.lower().endswith(".csv"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Expected a .csv file")

    svc = PricingService()
    ts = TypesenseService(get_typesense_client())

    inserted = 0
    feed: PricingFeedUpload | None = None
    try:
        raw = await file.read(settings.max_upload_bytes + 1)
        if len(raw) > settings.max_upload_bytes:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail="CSV file exceeds the maximum allowed size",
            )
        sha256 = hashlib.sha256(raw).hexdigest()

        feed = PricingFeedUpload(
            filename=file.filename,
            sha256=sha256,
            source="csv_upload",
            uploaded_by_user_id=actor.user_id,
            uploaded_by_api_key_id=actor.api_key_id,
            status="received",
            row_count=0,
        )
        db.add(feed)
        await db.commit()
        await db.refresh(feed)

        # streaming-ish processing using chunksize; pandas uses python file-like object
        # enforce dtype for critical cols; parse date
        # NOTE: asyncpg limits bind parameters to 32767; keep chunk size small enough for bulk upserts.
        chunks = pd.read_csv(
            io.BytesIO(raw),
            chunksize=2000,
            dtype={"store_id": "string", "sku": "string", "product_name": "string"},
        )
        row_offset = 0  # 0-based data-row offset (header excluded)
        while True:
            prepared = await asyncio.to_thread(_read_and_prepare_chunk, chunks, svc)
            if prepared is None:
                break

            records, record_count = prepared
            rows: list[dict] = []
            for idx, rec in enumerate(records):
                source_line = row_offset + idx + 2  # 1-based file line number; +1 for header
                rows.append(
                    {
                        "id": uuid.uuid4(),
                        "country_code": settings.default_country_code,
                        "store_id": str(rec["store_id"]),
                        "sku": str(rec["sku"]),
                        "product_name": str(rec["product_name"]),
                        "price": float(rec["price"]),
                        "currency_code": settings.default_currency_code,
                        "tax_inclusive": True,
                        "date": rec["date"] if isinstance(rec["date"], date) else pd.to_datetime(rec["date"]).date(),
                        "feed_id": feed.id,
                        "source_line": source_line,
                        "updated_by_user_id": actor.user_id,
                        "updated_source": "ingest",
                        "update_reason": None,
                    }
                )
            # "inserted" here really means "upserted" (processed). DB uniqueness prevents duplicates.
            inserted += await svc.persist_and_index_chunk(db, chunk_rows=rows, typesense=ts)
            row_offset += record_count

        feed.row_count = row_offset
        feed.status = "processed"
        await db.commit()
        await clear_pricing_search_caches()

        return {"inserted": inserted}
    except ValueError as e:
        await db.rollback()
        if feed is not None:
            feed.status = "failed"
            feed.error_report = str(e)
            db.add(feed)
            await db.commit()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)) from e
    except HTTPException:
        raise
    except Exception as e:
        logger.exception(
            "upload.csv_failed",
            filename=file.filename,
            content_type=file.content_type,
            error_type=type(e).__name__,
        )
        await db.rollback()
        if feed is not None:
            feed.status = "failed"
            feed.error_report = f"{type(e).__name__}: {str(e)}"
            db.add(feed)
            await db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid CSV payload ({type(e).__name__})",
        ) from e

