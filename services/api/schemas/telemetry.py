from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class TelemetryPoint(BaseModel):
    ts: datetime
    asset: str
    signal: str
    value: float
    quality: str
    state: str
