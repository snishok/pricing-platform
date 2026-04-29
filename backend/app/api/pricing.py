from __future__ import annotations

import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_db, require_roles, require_user_id
from app.core.roles import EDIT_ROLES
from app.core.typesense_client import get_typesense_client
from app.schemas.common import PaginatedResponse, PaginationMeta
from app.schemas.pricing import PricingRecordOut, PricingUpdateRequest
from app.services.pricing_service import PricingService
from app.services.typesense_service import TypesenseService


router = APIRouter(prefix="/pricing", tags=["pricing"])


@router.get("/search", response_model=PaginatedResponse[PricingRecordOut])
async def search_pricing(
    q: str | None = Query(default=None),
    store_id: str | None = Query(default=None),
    sku: str | None = Query(default=None),
    date_from: date | None = Query(default=None),
    date_to: date | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    per_page: int = Query(default=25, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    _: uuid.UUID = Depends(require_user_id),
) -> PaginatedResponse[PricingRecordOut]:
    svc = PricingService()
    ts = TypesenseService(get_typesense_client())
    try:
        res = await ts.search(
            q=q,
            store_id=store_id,
            sku=sku,
            date_from=date_from,
            date_to=date_to,
            page=page,
            per_page=per_page,
        )
        hits = res.get("hits", [])
        total = int(res.get("found", 0))

        # Fetch canonical rows from DB by id (keeps DB as source of truth)
        ids = [uuid.UUID(h["document"]["db_id"]) for h in hits if "document" in h and "db_id" in h["document"]]
        if not ids:
            return PaginatedResponse(
                data=[],
                pagination=PaginationMeta(page=page, per_page=per_page, total=total),
            )

        rows = await svc.get_by_ids(db, ids)
        out = [PricingRecordOut.model_validate(r, from_attributes=True) for r in rows]

        return PaginatedResponse(
            data=out,
            pagination=PaginationMeta(page=page, per_page=per_page, total=total),
        )
    except Exception:
        # fallback to DB ilike search if Typesense unavailable
        rows, total = await svc.db_fallback_search(
            db,
            q=q,
            store_id=store_id,
            sku=sku,
            date_from=date_from,
            date_to=date_to,
            page=page,
            per_page=per_page,
        )
        return PaginatedResponse(
            data=[PricingRecordOut.model_validate(r, from_attributes=True) for r in rows],
            pagination=PaginationMeta(page=page, per_page=per_page, total=total),
        )


@router.get("/{record_id}", response_model=PricingRecordOut)
async def get_pricing_record(
    record_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: uuid.UUID = Depends(require_user_id),
) -> PricingRecordOut:
    try:
        rec = await PricingService().get_by_id(db, record_id)
        return PricingRecordOut.model_validate(rec, from_attributes=True)
    except LookupError:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")


@router.put("/{record_id}", response_model=PricingRecordOut)
async def update_pricing_record(
    record_id: uuid.UUID,
    payload: PricingUpdateRequest,
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(require_user_id),
    _: object = Depends(require_roles(EDIT_ROLES)),
) -> PricingRecordOut:
    try:
        ts = TypesenseService(get_typesense_client())
        fields = payload.model_dump(exclude_none=True)
        rec = await PricingService().update_record(db, record_id=record_id, user_id=user_id, fields=fields, typesense=ts)
        return PricingRecordOut.model_validate(rec, from_attributes=True)
    except LookupError:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    except IntegrityError:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Conflict updating record")

