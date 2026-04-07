from __future__ import annotations

from typing import Annotated

import psycopg
from fastapi import APIRouter, Depends, Query

from services.api.dependencies import get_conn, require_api_key
from services.api.schemas.kpi import KpiSummary

router = APIRouter(prefix="/api/v1/kpis", tags=["kpis"])

_KPI_SQL = """
SELECT
    asset,
    display_name,
    asset_type,
    %s::float AS window_hours,
    total_readings,
    good_readings,
    CASE WHEN total_readings > 0
         THEN good_readings::float / total_readings
         ELSE 0 END AS quality_rate,
    running_minutes,
    fault_minutes,
    CASE WHEN (running_minutes + fault_minutes) > 0
         THEN running_minutes / (running_minutes + fault_minutes)
         ELSE 0 END AS availability,
    open_alert_count
FROM v_kpi_summary
ORDER BY asset
"""


@router.get("", response_model=list[KpiSummary], dependencies=[Depends(require_api_key)])
def get_kpis(
    conn: Annotated[psycopg.Connection, Depends(get_conn)],
    window: float = Query(8.0, ge=1.0, le=168.0, description="Rolling window in hours"),
):
    with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
        cur.execute(_KPI_SQL, (window,))
        return cur.fetchall()
