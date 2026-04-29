from __future__ import annotations

import uuid
from datetime import date as Date, datetime

from pydantic import BaseModel, Field, model_validator


class PricingRecordOut(BaseModel):
    id: uuid.UUID
    country_code: str
    store_id: str
    sku: str
    product_name: str
    price: float
    currency_code: str
    tax_inclusive: bool
    date: Date
    observed_at: datetime
    feed_id: uuid.UUID | None = None
    source_line: int | None = None
    updated_by_user_id: uuid.UUID | None = None
    updated_source: str
    update_reason: str | None = None
    created_at: datetime
    updated_at: datetime


class PricingUpdateRequest(BaseModel):
    country_code: str | None = Field(default=None, min_length=2, max_length=2)
    store_id: str | None = Field(default=None, min_length=1, max_length=64)
    sku: str | None = Field(default=None, min_length=1, max_length=128)
    product_name: str | None = Field(default=None, min_length=1)
    price: float | None = Field(default=None, ge=0)
    currency_code: str | None = Field(default=None, min_length=3, max_length=3)
    tax_inclusive: bool | None = None
    date: Date | None = None
    update_reason: str | None = Field(default=None, max_length=2000)

    @model_validator(mode="after")
    def _at_least_one_field(self) -> "PricingUpdateRequest":
        if (
            self.country_code is None
            and self.store_id is None
            and self.sku is None
            and self.product_name is None
            and self.price is None
            and self.currency_code is None
            and self.tax_inclusive is None
            and self.date is None
            and self.update_reason is None
        ):
            raise ValueError("At least one field must be provided")
        return self


class PricingSearchQuery(BaseModel):
    q: str | None = Field(default=None, description="Full-text query for product_name")
    country_code: str | None = None
    store_id: str | None = None
    sku: str | None = None
    date_from: Date | None = None
    date_to: Date | None = None
    page: int = Field(default=1, ge=1)
    per_page: int = Field(default=25, ge=1, le=200)

