from __future__ import annotations

import asyncio
from typing import Any

import typesense

from app.core.config import settings
from app.core.logging import logger


def get_typesense_client() -> typesense.Client:
    return typesense.Client(
        {
            "api_key": settings.typesense_api_key,
            "nodes": [
                {
                    "host": settings.typesense_host,
                    "port": settings.typesense_port,
                    "protocol": settings.typesense_protocol,
                }
            ],
            "connection_timeout_seconds": 5,
        }
    )


PRICING_COLLECTION_SCHEMA: dict[str, Any] = {
    "name": settings.typesense_collection,
    "fields": [
        {"name": "store_id", "type": "string", "facet": True},
        {"name": "sku", "type": "string", "facet": True},
        {"name": "product_name", "type": "string"},
        {"name": "price", "type": "float"},
        {"name": "date", "type": "int64", "facet": True},
        {"name": "db_id", "type": "string"},
    ],
    "default_sorting_field": "date",
}


async def ensure_pricing_collection(client: typesense.Client) -> None:
    # typesense python client is sync; run in thread to keep FastAPI async clean
    def _ensure() -> None:
        try:
            client.collections[settings.typesense_collection].retrieve()
            return
        except Exception:
            client.collections.create(PRICING_COLLECTION_SCHEMA)

    await asyncio.to_thread(_ensure)
    logger.info("typesense.collection_ready", collection=settings.typesense_collection)

