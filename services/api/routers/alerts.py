from __future__ import annotations

from typing import Annotated
from uuid import UUID

import psycopg
from fastapi import APIRouter, Depends, HTTPException, Query, status

from services.api.dependencies import get_conn, require_api_key
from services.api.schemas.alert import AcknowledgeRequest, AlertOut

router = APIRouter(prefix="/api/v1/alerts", tags=["alerts"])

_LIST_SQL = """
SELECT id, opened_at, site, line_name, asset, asset_display_name,
       signal, alert_type, severity, value, threshold,
       state, message, acked_at, closed_at, rule_id
FROM v_recent_alerts
WHERE (%s::text IS NULL OR state = %s)
  AND (%s::text IS NULL OR asset = %s)
ORDER BY opened_at DESC
LIMIT %s
"""

_ACK_SQL = """
UPDATE alerts
SET state = 'ACKED', acked_at = now()
WHERE id = %s::uuid AND state = 'OPEN'
RETURNING id::text
"""


@router.get("", response_model=list[AlertOut], dependencies=[Depends(require_api_key)])
def list_alerts(
    conn: Annotated[psycopg.Connection, Depends(get_conn)],
    state: str | None = Query(None, pattern="^(OPEN|ACKED|CLOSED)$"),
    asset: str | None = Query(None),
    limit: int = Query(100, ge=1, le=1000),
):
    with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
        cur.execute(_LIST_SQL, (state, state, asset, asset, limit))
        return cur.fetchall()


@router.post(
    "/{alert_id}/acknowledge",
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(require_api_key)],
)
def acknowledge_alert(
    alert_id: UUID,
    _body: AcknowledgeRequest,
    conn: Annotated[psycopg.Connection, Depends(get_conn)],
):
    with conn.cursor() as cur:
        cur.execute(_ACK_SQL, (str(alert_id),))
        row = cur.fetchone()
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert not found or already acknowledged/closed",
        )
    conn.commit()
    return {"id": str(alert_id), "state": "ACKED"}
