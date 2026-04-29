from __future__ import annotations

import uuid
from datetime import date, datetime

from sqlalchemy import Boolean, CheckConstraint, Date, DateTime, ForeignKey, Index, Integer, Numeric, String, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.core.config import settings


class PricingRecord(Base):
    __tablename__ = "pricing_records"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    country_code: Mapped[str] = mapped_column(String(2), index=True, nullable=False, default=settings.default_country_code)
    store_id: Mapped[str] = mapped_column(String(64), index=True, nullable=False)
    sku: Mapped[str] = mapped_column(String(128), index=True, nullable=False)
    product_name: Mapped[str] = mapped_column(Text, nullable=False)
    price: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    currency_code: Mapped[str] = mapped_column(String(3), index=True, nullable=False, default=settings.default_currency_code)
    tax_inclusive: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    # Effective date of the price in the feed (business date)
    date: Mapped[date] = mapped_column(Date, index=True, nullable=False)
    # When we observed/ingested it (system timestamp)
    observed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # Provenance
    feed_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("pricing_feed_uploads.id"), index=True, nullable=True)
    source_line: Mapped[int | None] = mapped_column(Integer, nullable=True)

    # "Last editor" / last change metadata
    updated_by_user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), index=True, nullable=True)
    updated_source: Mapped[str] = mapped_column(String(32), nullable=False, default="ingest")  # ingest|manual|api
    update_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    __table_args__ = (
        CheckConstraint("price >= 0", name="ck_pricing_records_price_non_negative"),
        UniqueConstraint("country_code", "store_id", "sku", "date", name="uq_pricing_records_country_store_sku_date"),
        Index("ix_pricing_records_country_store_sku_date", "country_code", "store_id", "sku", "date"),
    )

