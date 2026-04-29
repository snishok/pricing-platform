from __future__ import annotations

import asyncio

from sqlalchemy import text

from app.core.config import settings
from app.core.db import engine
from app.core.logging import configure_logging, logger


async def run_retention() -> int:
    """
    Deletes pricing records older than settings.pricing_retention_days based on business date.
    Returns number of rows deleted.
    """
    async with engine.begin() as conn:
        res = await conn.execute(
            text(
                """
                DELETE FROM pricing_records
                WHERE date < (CURRENT_DATE - (:days || ' days')::interval)
                """
            ),
            {"days": int(settings.pricing_retention_days)},
        )
        return int(res.rowcount or 0)


def main() -> None:
    configure_logging(settings.environment)

    deleted = asyncio.run(run_retention())
    logger.info("retention.pricing_records_deleted", days=settings.pricing_retention_days, deleted=deleted)


if __name__ == "__main__":
    main()

