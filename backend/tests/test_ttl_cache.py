from app.core.ttl_cache import TTLCache


def test_ttl_cache_returns_value_before_expiry():
    now = 100.0
    cache = TTLCache[str, dict](max_size=10, ttl_seconds=30, timer=lambda: now)

    cache.set("search:milk", {"total": 1})

    assert cache.get("search:milk") == {"total": 1}


def test_ttl_cache_expires_values():
    current_time = 100.0
    cache = TTLCache[str, dict](max_size=10, ttl_seconds=30, timer=lambda: current_time)

    cache.set("search:milk", {"total": 1})
    current_time = 131.0

    assert cache.get("search:milk") is None


def test_ttl_cache_evicts_oldest_when_full():
    current_time = 100.0
    cache = TTLCache[str, int](max_size=2, ttl_seconds=30, timer=lambda: current_time)

    cache.set("first", 1)
    cache.set("second", 2)
    cache.set("third", 3)

    assert cache.get("first") is None
    assert cache.get("second") == 2
    assert cache.get("third") == 3


def test_ttl_cache_clear_removes_values():
    cache = TTLCache[str, int](max_size=2, ttl_seconds=30)

    cache.set("first", 1)
    cache.clear()

    assert cache.get("first") is None
