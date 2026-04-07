from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class AlertOut(BaseModel):
    id: UUID
    opened_at: datetime
    site: str
    line_name: str
    asset: str
    asset_display_name: str | None
    signal: str
    alert_type: str
    severity: str
    value: float
    threshold: float | None
    state: str
    message: str
    acked_at: datetime | None
    closed_at: datetime | None
    rule_id: UUID | None


class AcknowledgeRequest(BaseModel):
    note: str = ""
