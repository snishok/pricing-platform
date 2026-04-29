from __future__ import annotations

from pydantic import AnyUrl
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_name: str = "pricing-platform-api"
    environment: str = "dev"

    cors_origins: list[str] = ["http://localhost:8080", "http://localhost:3000"]

    database_url: str

    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    jwt_access_token_expires_minutes: int = 60

    seed_admin_email: str | None = None
    seed_admin_password: str | None = None

    seed_viewer_email: str | None = None
    seed_viewer_password: str | None = None

    seed_editor_email: str | None = None
    seed_editor_password: str | None = None

    seed_uploader_email: str | None = None
    seed_uploader_password: str | None = None

    typesense_api_key: str
    typesense_host: str = "typesense"
    typesense_port: int = 8108
    typesense_protocol: str = "http"
    typesense_collection: str = "pricing"
    typesense_max_concurrency: int = 16

    rate_limit_enabled: bool = True
    rate_limit_per_minute: str = "600/minute"
    rate_limit_storage_uri: str | None = None

    db_pool_size: int = 5
    db_max_overflow: int = 10
    db_pool_timeout_seconds: int = 30
    db_pool_recycle_seconds: int = 1800

    search_cache_ttl_seconds: int = 15
    search_cache_max_entries: int = 512
    search_cache_redis_url: str | None = None

    max_upload_bytes: int = 50 * 1024 * 1024

    # Data normalization defaults (used when feeds omit these fields)
    default_country_code: str = "XX"
    default_currency_code: str = "USD"

    # Partitioning & retention (production options; safe defaults)
    enable_pricing_partitioning: bool = False
    pricing_partition_months_ahead: int = 3
    pricing_partition_months_backfill: int = 12
    pricing_retention_days: int = 730

    def typesense_url(self) -> AnyUrl:
        return AnyUrl.build(
            scheme=self.typesense_protocol,
            host=self.typesense_host,
            port=self.typesense_port,
        )


settings = Settings()

