from __future__ import annotations

import asyncio
import math
from datetime import date, datetime, time, timezone
from typing import Any
from weakref import WeakKeyDictionary

import typesense

from app.core.config import settings


_typesense_semaphores: WeakKeyDictionary[asyncio.AbstractEventLoop, asyncio.Semaphore] = WeakKeyDictionary()


def _get_typesense_semaphore() -> asyncio.Semaphore:
    loop = asyncio.get_running_loop()
    semaphore = _typesense_semaphores.get(loop)
    if semaphore is None:
        semaphore = asyncio.Semaphore(settings.typesense_max_concurrency)
        _typesense_semaphores[loop] = semaphore
    return semaphore


def _to_typesense_date(d: date) -> int:
    dt = datetime.combine(d, time.min).replace(tzinfo=timezone.utc)
    return int(dt.timestamp())


class TypesenseService:
    def __init__(self, client: typesense.Client) -> None:
        self._client = client

    def _build_filter_by(
        self,
        *,
        country_code: str | None,
        store_ids: list[str] | None,
        skus: list[str] | None,
        date_from: date | None,
        date_to: date | None,
    ) -> str | None:
        filter_parts: list[str] = []
        if country_code:
            filter_parts.append(f'country_code:="{country_code}"')

        if store_ids:
            parts = [f'store_id:="{v}"' for v in store_ids if v]
            if parts:
                filter_parts.append(f"({ ' || '.join(parts) })")

        if skus:
            parts = [f'sku:="{v}"' for v in skus if v]
            if parts:
                filter_parts.append(f"({ ' || '.join(parts) })")

        if date_from or date_to:
            lo = _to_typesense_date(date_from) if date_from else -math.inf
            hi = _to_typesense_date(date_to) if date_to else math.inf
            if lo == -math.inf:
                filter_parts.append(f"date:<= {int(hi)}")
            elif hi == math.inf:
                filter_parts.append(f"date:>= {int(lo)}")
            else:
                filter_parts.append(f"date: [{int(lo)}..{int(hi)}]")

        return " && ".join(filter_parts) if filter_parts else None

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
                async with _get_typesense_semaphore():
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

        async with _get_typesense_semaphore():
            await asyncio.to_thread(_update)

    async def update_pricing_record(self, *, record_id: str, fields: dict[str, Any]) -> None:
        if not fields:
            return

        payload: dict[str, Any] = dict(fields)
        if "date" in payload and isinstance(payload["date"], date):
            payload["date"] = _to_typesense_date(payload["date"])

        def _update() -> None:
            self._client.collections[settings.typesense_collection].documents[record_id].update(payload)

        async with _get_typesense_semaphore():
            await asyncio.to_thread(_update)

    async def search(
        self,
        *,
        q: str | None,
        country_code: str | None,
        store_ids: list[str] | None,
        skus: list[str] | None,
        date_from: date | None,
        date_to: date | None,
        page: int,
        per_page: int,
    ) -> dict[str, Any]:
        filter_by = self._build_filter_by(
            country_code=country_code,
            store_ids=store_ids,
            skus=skus,
            date_from=date_from,
            date_to=date_to,
        )

        search_params: dict[str, Any] = {
            "q": q or "*",
            "query_by": "product_name",
            # Make search feel more "elastic" while typing/partial queries.
            "prefix": "true",
            "num_typos": 2,
            "min_len_1typo": 3,
            "min_len_2typo": 6,
            "page": page,
            "per_page": per_page,
            "typo_tokens_threshold": 1,
        }
        if filter_by:
            search_params["filter_by"] = filter_by

        def _search() -> dict[str, Any]:
            return self._client.collections[settings.typesense_collection].documents.search(search_params)

        async with _get_typesense_semaphore():
            return await asyncio.to_thread(_search)

    async def search_meta(
        self,
        *,
        q: str | None,
        country_code: str | None,
        store_ids: list[str] | None,
        skus: list[str] | None,
        date_from: date | None,
        date_to: date | None,
        max_facet_values: int = 50,
        suggestions_limit: int = 8,
    ) -> dict[str, Any]:
        """
        Returns Typesense facet counts + lightweight suggestions for the current query context.
        """
        filter_by = self._build_filter_by(
            country_code=country_code,
            store_ids=store_ids,
            skus=skus,
            date_from=date_from,
            date_to=date_to,
        )

        # Facets over the current result set.
        facet_params: dict[str, Any] = {
            "q": q or "*",
            "query_by": "product_name",
            "page": 1,
            "per_page": 1,
            "facet_by": "store_id,sku",
            "max_facet_values": max_facet_values,
        }
        if filter_by:
            facet_params["filter_by"] = filter_by

        def _facet_search() -> dict[str, Any]:
            return self._client.collections[settings.typesense_collection].documents.search(facet_params)

        async with _get_typesense_semaphore():
            facets = await asyncio.to_thread(_facet_search)

        # Suggestions based on typed query (only when user is typing).
        suggestions: list[str] = []
        q_trim = (q or "").strip()
        if q_trim:
            suggest_params: dict[str, Any] = {
                "q": q_trim,
                "query_by": "product_name",
                "prefix": "true",
                "num_typos": 2,
                "min_len_1typo": 3,
                "min_len_2typo": 6,
                "prioritize_exact_match": "true",
                "prioritize_token_position": "true",
                "page": 1,
                "per_page": suggestions_limit,
                "typo_tokens_threshold": 1,
            }
            if filter_by:
                suggest_params["filter_by"] = filter_by

            def _suggest_search() -> dict[str, Any]:
                return self._client.collections[settings.typesense_collection].documents.search(suggest_params)

            async with _get_typesense_semaphore():
                suggest_res = await asyncio.to_thread(_suggest_search)
            seen: set[str] = set()
            for h in suggest_res.get("hits", []) or []:
                doc = (h or {}).get("document") or {}
                name = doc.get("product_name")
                if isinstance(name, str):
                    name = name.strip()
                    if name and name not in seen:
                        seen.add(name)
                        suggestions.append(name)

        return {
            "found": int(facets.get("found", 0)),
            "facet_counts": facets.get("facet_counts", []),
            "suggestions": suggestions,
        }

