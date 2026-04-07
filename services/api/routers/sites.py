from __future__ import annotations

from typing import Annotated

import psycopg
from fastapi import APIRouter, Depends

from services.api.dependencies import get_conn, require_api_key
from services.api.schemas.kpi import SiteSummary

router = APIRouter(prefix="/api/v1/sites", tags=["sites"])

_LIST_SQL = """
SELECT site_id, display_name, location, timezone, active
FROM sites
ORDER BY site_id
"""


@router.get("", response_model=list[SiteSummary], dependencies=[Depends(require_api_key)])
def list_sites(conn: Annotated[psycopg.Connection, Depends(get_conn)]):
    with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
        cur.execute(_LIST_SQL)
        return cur.fetchall()
