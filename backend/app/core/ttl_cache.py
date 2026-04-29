from __future__ import annotations

import time
from collections import OrderedDict
from collections.abc import Callable
from dataclasses import dataclass
from threading import RLock
from typing import Generic, TypeVar


K = TypeVar("K")
V = TypeVar("V")


@dataclass(frozen=True)
class _CacheEntry(Generic[V]):
    value: V
    expires_at: float


class TTLCache(Generic[K, V]):
    def __init__(
        self,
        *,
        max_size: int,
        ttl_seconds: int,
        timer: Callable[[], float] = time.monotonic,
    ) -> None:
        self._max_size = max(0, max_size)
        self._ttl_seconds = max(0, ttl_seconds)
        self._timer = timer
        self._values: OrderedDict[K, _CacheEntry[V]] = OrderedDict()
        self._lock = RLock()

    def get(self, key: K) -> V | None:
        if self._max_size == 0 or self._ttl_seconds == 0:
            return None

        with self._lock:
            entry = self._values.get(key)
            if entry is None:
                return None

            if entry.expires_at <= self._timer():
                self._values.pop(key, None)
                return None

            self._values.move_to_end(key)
            return entry.value

    def set(self, key: K, value: V) -> None:
        if self._max_size == 0 or self._ttl_seconds == 0:
            return

        with self._lock:
            self._values[key] = _CacheEntry(value=value, expires_at=self._timer() + self._ttl_seconds)
            self._values.move_to_end(key)

            while len(self._values) > self._max_size:
                self._values.popitem(last=False)

    def clear(self) -> None:
        with self._lock:
            self._values.clear()
