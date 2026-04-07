from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class AssetSummary(BaseModel):
    asset: str
    display_name: str
    asset_type: str
    site: str
    line_name: str
    cell_name: str | None
    state: str
    fault_code: int
    quality: str
    last_seen: datetime | None
    open_alert_count: int


class AssetStatus(BaseModel):
    asset: str
    state: str
    fault_code: int
    quality: str
    last_seen: datetime | None
    open_alert_count: int
