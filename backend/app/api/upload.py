from __future__ import annotations

import uuid
from datetime import date

import pandas as pd
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_db, require_user_id
from app.core.typesense_client import get_typesense_client
from app.services.pricing_service import PricingService
from app.services.typesense_service import TypesenseService


router = APIRouter(tags=["upload"])


@router.post("/upload-csv")
async def upload_csv(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    _: uuid.UUID = Depends(require_user_id),
) -> dict[str, int]:
    if not file.filename or not file.filename.lower().endswith(".csv"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Expected a .csv file")

    svc = PricingService()
    ts = TypesenseService(get_typesense_client())

    inserted = 0
    try:
        # streaming-ish processing using chunksize; pandas uses python file-like object
        # enforce dtype for critical cols; parse date
        chunks = pd.read_csv(
            file.file,
            chunksize=5000,
            dtype={"store_id": "string", "sku": "string", "product_name": "string"},
        )
        for chunk in chunks:
            svc.validate_csv_columns(set(chunk.columns))

            chunk = chunk.copy()
            chunk["date"] = pd.to_datetime(chunk["date"], errors="raise").dt.date
            chunk["price"] = pd.to_numeric(chunk["price"], errors="raise")

            rows: list[dict] = []
            for rec in chunk.to_dict(orient="records"):
                rows.append(
                    {
                        "id": uuid.uuid4(),
                        "store_id": str(rec["store_id"]),
                        "sku": str(rec["sku"]),
                        "product_name": str(rec["product_name"]),
                        "price": float(rec["price"]),
                        "date": rec["date"] if isinstance(rec["date"], date) else pd.to_datetime(rec["date"]).date(),
                    }
                )
            # "inserted" here really means "upserted" (processed). DB uniqueness prevents duplicates.
            inserted += await svc.persist_and_index_chunk(db, chunk_rows=rows, typesense=ts)

        return {"inserted": inserted}
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid CSV payload")

