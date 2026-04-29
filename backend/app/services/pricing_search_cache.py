from __future__ import annotations

import hashlib
import json
from datetime import date
from functools import lru_cache
from typing import Any

import redis.asyncio as redis

from app.core.config import settings
from app.core.ttl_cache import TTLCache


PricingCacheKey = tuple[Any, ...]
_CACHE_PREFIX = "pricing-search-cache"

_pricing_search_cache = TTLCache[PricingCacheKey, dict[str, Any]](
    max_size=settings.search_cache_max_entries,
    ttl_seconds=settings.search_cache_ttl_seconds,
)
_pricing_meta_cache = TTLCache[PricingCacheKey, dict[str, Any]](
    max_size=settings.search_cache_max_entries,
    ttl_seconds=settings.search_cache_ttl_seconds,
)


def make_pricing_cache_key(
    *,
    scope: str,
    q: str | None,
    country_code: str | None,
    store_ids: list[str] | None,
    skus: list[str] | None,
    date_from: date | None,
    date_to: date | None,
    page: int | None = None,
    per_page: int | None = None,
) -> PricingCacheKey:
    return (
        scope,
        (q or "").strip(),
        country_code or "",
        tuple(sorted(v for v in store_ids or [] if v)),
        tuple(sorted(v for v in skus or [] if v)),
        date_from.isoformat() if date_from else "",
        date_to.isoformat() if date_to else "",
        page,
        per_page,
    )


def _redis_url() -> str | None:
    url = settings.search_cache_redis_url
    if not url or not url.startswith("redis://"):
        return None
    return url


@lru_cache(maxsize=1)
def _redis_client() -> redis.Redis | None:
    url = _redis_url()
    if not url:
        return None
    return redis.from_url(url, decode_responses=True)


def _redis_key(cache_key: PricingCacheKey) -> str:
    raw = json.dumps(cache_key, default=str, separators=(",", ":"), sort_keys=True)
    digest = hashlib.sha256(raw.encode("utf-8")).hexdigest()
    return f"{_CACHE_PREFIX}:{digest}"


def _memory_cache(scope: str) -> TTLCache[PricingCacheKey, dict[str, Any]]:
    return _pricing_meta_cache if scope == "meta" else _pricing_search_cache


async def get_cached_pricing_response(cache_key: PricingCacheKey) -> dict[str, Any] | None:
    client = _redis_client()
    if client is not None:
        try:
            cached = await client.get(_redis_key(cache_key))
            return json.loads(cached) if cached else None
        except Exception:
            return None

    return _memory_cache(str(cache_key[0])).get(cache_key)


async def set_cached_pricing_response(cache_key: PricingCacheKey, value: dict[str, Any]) -> None:
    if settings.search_cache_ttl_seconds <= 0:
        return

    client = _redis_client()
    if client is not None:
        try:
            await client.setex(_redis_key(cache_key), settings.search_cache_ttl_seconds, json.dumps(value, default=str))
        except Exception:
            return
        return

    _memory_cache(str(cache_key[0])).set(cache_key, value)


async def clear_pricing_search_caches() -> None:
    _pricing_search_cache.clear()
    _pricing_meta_cache.clear()

    client = _redis_client()
    if client is None:
        return

    try:
        keys = [key async for key in client.scan_iter(f"{_CACHE_PREFIX}:*")]
        if keys:
            await client.delete(*keys)
    except Exception:
        return
