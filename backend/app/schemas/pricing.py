from __future__ import annotations

import uuid
from datetime import date as Date, datetime

from pydantic import BaseModel, Field, model_validator


class PricingRecordOut(BaseModel):
    id: uuid.UUID
    store_id: str
    sku: str
    product_name: str
    price: float
    date: Date
    created_at: datetime
    updated_at: datetime


class PricingUpdateRequest(BaseModel):
    store_id: str | None = Field(default=None, min_length=1, max_length=64)
    sku: str | None = Field(default=None, min_length=1, max_length=128)
    product_name: str | None = Field(default=None, min_length=1)
    price: float | None = Field(default=None, gt=0)
    date: Date | None = None

    @model_validator(mode="after")
    def _at_least_one_field(self) -> "PricingUpdateRequest":
        if (
            self.store_id is None
            and self.sku is None
            and self.product_name is None
            and self.price is None
            and self.date is None
        ):
            raise ValueError("At least one field must be provided")
        return self


class PricingSearchQuery(BaseModel):
    q: str | None = Field(default=None, description="Full-text query for product_name")
    store_id: str | None = None
    sku: str | None = None
    date_from: Date | None = None
    date_to: Date | None = None
    page: int = Field(default=1, ge=1)
    per_page: int = Field(default=25, ge=1, le=200)

