from __future__ import annotations

import asyncio
import math
from datetime import date, datetime, time, timezone
from typing import Any

import typesense

from app.core.config import settings


def _to_typesense_date(d: date) -> int:
    dt = datetime.combine(d, time.min).replace(tzinfo=timezone.utc)
    return int(dt.timestamp())


class TypesenseService:
    def __init__(self, client: typesense.Client) -> None:
        self._client = client

    async def upsert_documents_with_retry(self, docs: list[dict[str, Any]], *, max_attempts: int = 5) -> None:
        if not docs:
            return

        def _import() -> None:
            self._client.collections[settings.typesense_collection].documents.import_(
                docs,
                {"action": "upsert"},
            )

        delay = 0.3
        for attempt in range(1, max_attempts + 1):
            try:
                await asyncio.to_thread(_import)
                return
            except Exception:
                if attempt == max_attempts:
                    raise
                await asyncio.sleep(delay)
                delay = min(delay * 2, 3.0)

    async def upsert_pricing_records(self, records: list[dict[str, Any]]) -> None:
        docs: list[dict[str, Any]] = []
        for r in records:
            docs.append(
                {
                    "id": str(r["id"]),
                    "db_id": str(r["id"]),
                    "country_code": r.get("country_code", "XX"),
                    "store_id": r["store_id"],
                    "sku": r["sku"],
                    "product_name": r["product_name"],
                    "price": float(r["price"]),
                    "currency_code": r.get("currency_code", "USD"),
                    "tax_inclusive": bool(r.get("tax_inclusive", True)),
                    "date": _to_typesense_date(r["date"]),
                }
            )
        await self.upsert_documents_with_retry(docs)

    async def update_price(self, *, record_id: str, price: float) -> None:
        def _update() -> None:
            self._client.collections[settings.typesense_collection].documents[record_id].update({"price": price})

        await asyncio.to_thread(_update)

    async def update_pricing_record(self, *, record_id: str, fields: dict[str, Any]) -> None:
        if not fields:
            return

        payload: dict[str, Any] = dict(fields)
        if "date" in payload and isinstance(payload["date"], date):
            payload["date"] = _to_typesense_date(payload["date"])

        def _update() -> None:
            self._client.collections[settings.typesense_collection].documents[record_id].update(payload)

        await asyncio.to_thread(_update)

    async def search(
        self,
        *,
        q: str | None,
        country_code: str | None,
        store_id: str | None,
        sku: str | None,
        date_from: date | None,
        date_to: date | None,
        page: int,
        per_page: int,
    ) -> dict[str, Any]:
        filter_parts: list[str] = []
        if country_code:
            filter_parts.append(f'country_code:="{country_code}"')
        if store_id:
            filter_parts.append(f'store_id:="{store_id}"')
        if sku:
            filter_parts.append(f'sku:="{sku}"')
        if date_from or date_to:
            lo = _to_typesense_date(date_from) if date_from else -math.inf
            hi = _to_typesense_date(date_to) if date_to else math.inf
            if lo == -math.inf:
                filter_parts.append(f"date:<= {int(hi)}")
            elif hi == math.inf:
                filter_parts.append(f"date:>= {int(lo)}")
            else:
                filter_parts.append(f"date: [{int(lo)}..{int(hi)}]")

        filter_by = " && ".join(filter_parts) if filter_parts else None

        search_params: dict[str, Any] = {
            "q": q or "*",
            "query_by": "product_name",
            "page": page,
            "per_page": per_page,
            "typo_tokens_threshold": 1,
        }
        if filter_by:
            search_params["filter_by"] = filter_by

        def _search() -> dict[str, Any]:
            return self._client.collections[settings.typesense_collection].documents.search(search_params)

        return await asyncio.to_thread(_search)

