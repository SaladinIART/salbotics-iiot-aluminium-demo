"""GET /api/v1/dashboard — Executive summary for the management demo.

Aggregates asset states, business impact, maintenance status, and order risk
into a single response designed for the Executive Dashboard frontend page.
"""
from __future__ import annotations

import os
from typing import Annotated

import httpx
import psycopg
from fastapi import APIRouter, Depends

from services.api.dependencies import get_conn, require_api_key
from services.api.schemas.dashboard import (
    AssetSummaryForDashboard,
    DashboardResponse,
    FinancialSummary,
    LogisticsStatus,
    MaintenanceStatus,
    OrderSummary,
    ProductionStatus,
    RecommendedAction,
)

router = APIRouter(prefix="/api/v1/dashboard", tags=["dashboard"])

# Where the modbus_sim scenario API lives (override via env var for local dev)
_SIM_BASE = os.getenv("MODBUS_SIM_API", "http://modbus-sim:5001")

# MTTR estimates per fault code (minutes) — informed by maintenance_log history
_MTTR_MAP = {
    101: 20,   # feeder LOW_MATERIAL — refill hopper
    102: 240,  # feeder MOTOR_TRIP — motor inspection, possible replacement
    201: 90,   # mixer HIGH_TEMP — cooling loop flush / fan replacement
    202: 60,   # mixer LOW_PRESSURE — regulator check/replacement
    301: 45,   # conveyor JAM — clear jam + restart test
    302: 60,   # conveyor SPEED_VARIANCE — encoder/tensioner check
    401: 15,   # packer FILM_BREAK — roll replacement
    402: 90,   # packer SEAL_TEMP_LOW — heating element / thermostat
}

_RECOMMENDED_ACTIONS: dict[str, list[dict]] = {
    "NORMAL": [
        {"urgency": "INFO", "owner": "MANAGEMENT", "action": "All systems nominal — no action required"},
    ],
    "QUALITY_HOLD": [
        {"urgency": "URGENT",    "owner": "MAINTENANCE",  "action": "Inspect reflow oven cooling loop — schedule PM within 4 hours"},
        {"urgency": "URGENT",    "owner": "PRODUCTION",   "action": "Place Batch #2024-034 (85 units) on quality hold for re-inspection"},
        {"urgency": "SOON",      "owner": "LOGISTICS",    "action": "Notify Intel Penang: PO-2024-089 may slip 2 hours — confirm acceptance"},
        {"urgency": "SOON",      "owner": "MANAGEMENT",   "action": "Approve quality inspection (3 hr) — no customer impact if approved now"},
    ],
    "LINE_FAULT": [
        {"urgency": "IMMEDIATE", "owner": "MANAGEMENT",   "action": "Approve RM 450 expedite courier for PO-2024-089 — decision needed within 20 min"},
        {"urgency": "IMMEDIATE", "owner": "MAINTENANCE",  "action": "Dispatch technician — conveyor jam clearance ETA 30 min, then packer film roll"},
        {"urgency": "URGENT",    "owner": "LOGISTICS",    "action": "Book expedite courier before 14:00 cut-off to save Intel Penang delivery"},
        {"urgency": "URGENT",    "owner": "PRODUCTION",   "action": "Pre-stage PO-2024-089 units for priority packing on line restart"},
    ],
    "EMERGENCY": [
        {"urgency": "IMMEDIATE", "owner": "MANAGEMENT",   "action": "Invoke BCP — approve CM transfer to Contract Manufacturer B (RM 8,500 premium)"},
        {"urgency": "IMMEDIATE", "owner": "MANAGEMENT",   "action": "Approve air freight for Intel Penang (RM 12,000) — saves RM 50,000 penalty"},
        {"urgency": "IMMEDIATE", "owner": "MANAGEMENT",   "action": "Call Intel Penang, Bosch Malaysia, Siemens Penang account managers NOW"},
        {"urgency": "IMMEDIATE", "owner": "MAINTENANCE",  "action": "EHS area isolation required before any technician entry — raise emergency motor PO"},
        {"urgency": "URGENT",    "owner": "LOGISTICS",    "action": "Complete CM transfer form — requires Plant Manager signature"},
        {"urgency": "URGENT",    "owner": "PRODUCTION",   "action": "Freeze all non-emergency production orders pending BCP activation"},
    ],
}

_ASSET_ICONS = {
    "feeder":   "component_feeder",
    "mixer":    "reflow_oven",
    "conveyor": "aoi_conveyor",
    "packer":   "test_pack",
}

_ASSET_SQL = """
SELECT
    b.asset,
    b.display_name,
    a.asset_type,
    b.state,
    b.fault_code,
    b.cost_rate_myr_hr,
    b.cost_so_far_myr,
    m.last_maint_at,
    m.pm_risk
FROM v_business_impact b
JOIN v_asset_current_state a ON a.asset = b.asset
LEFT JOIN v_maintenance_status m ON m.asset = b.asset
ORDER BY b.asset
"""

_ORDER_SQL = """
SELECT
    id, customer, quantity_ordered, due_at,
    order_value_myr, computed_status
FROM v_order_risk
ORDER BY due_at
"""

_PACKED_TODAY_SQL = """
SELECT COALESCE(MAX(value::bigint), 0) AS packed_today
FROM telemetry
WHERE asset = 'packer-01'
  AND signal = 'packed_count'
  AND ts >= CURRENT_DATE
"""

_SCHEDULE_SQL = """
SELECT target_units
FROM production_schedule
WHERE shift_date = CURRENT_DATE
  AND shift_name = 'Morning'
LIMIT 1
"""


def _get_scenario() -> dict:
    try:
        resp = httpx.get(f"{_SIM_BASE}/scenario", timeout=2.0)
        return resp.json()
    except Exception:
        return {"scenario": "NORMAL", "health": "GREEN", "message": "Scenario API unavailable"}


@router.get("", response_model=DashboardResponse, dependencies=[Depends(require_api_key)])
def get_dashboard(conn: Annotated[psycopg.Connection, Depends(get_conn)]) -> DashboardResponse:
    scenario_info = _get_scenario()
    scenario = scenario_info.get("scenario", "NORMAL")
    health = scenario_info.get("health", "GREEN")
    health_message = scenario_info.get("message", "")

    with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
        # Assets + business impact
        cur.execute(_ASSET_SQL)
        asset_rows = cur.fetchall()

        # Orders
        cur.execute(_ORDER_SQL)
        order_rows = cur.fetchall()

        # Production
        cur.execute(_PACKED_TODAY_SQL)
        packed_row = cur.fetchone()
        cur.execute(_SCHEDULE_SQL)
        schedule_row = cur.fetchone()

    # ── Financial ──────────────────────────────────────────────────────────────
    total_cost_rate = sum(float(r["cost_rate_myr_hr"] or 0) for r in asset_rows)
    total_cost_so_far = sum(float(r["cost_so_far_myr"] or 0) for r in asset_rows)

    at_risk_orders = [o for o in order_rows if o["computed_status"] in ("AT_RISK", "DELAYED")]
    at_risk_value = sum(float(o["order_value_myr"] or 0) for o in at_risk_orders)

    financial = FinancialSummary(
        cost_rate_myr_hr=round(total_cost_rate, 2),
        cost_so_far_myr=round(total_cost_so_far, 2),
        orders_at_risk_count=len(at_risk_orders),
        orders_at_risk_value_myr=round(at_risk_value, 2),
    )

    # ── Recommended actions ────────────────────────────────────────────────────
    actions_raw = _RECOMMENDED_ACTIONS.get(scenario, _RECOMMENDED_ACTIONS["NORMAL"])
    recommended_actions = [RecommendedAction(**a) for a in actions_raw]

    # ── Production ────────────────────────────────────────────────────────────
    faulted = [r for r in asset_rows if r["state"] in ("FAULTED", "MAINTENANCE")]
    units_today = int(packed_row["packed_today"]) if packed_row else 0
    target_today = int(schedule_row["target_units"]) if schedule_row else 850

    # Rough throughput estimate: if any machine faulted → proportional reduction
    running_count = sum(1 for r in asset_rows if r["state"] == "RUNNING")
    throughput_pct = round((running_count / max(len(asset_rows), 1)) * 100, 1)

    production = ProductionStatus(
        throughput_pct=throughput_pct,
        units_today=units_today,
        target_today=target_today,
        faulted_machine_count=len(faulted),
    )

    # ── Maintenance ───────────────────────────────────────────────────────────
    healthy = sum(1 for r in asset_rows if r["state"] not in ("FAULTED", "MAINTENANCE") and r.get("pm_risk") == "LOW")
    at_risk_pm = sum(1 for r in asset_rows if r.get("pm_risk") in ("MEDIUM", "HIGH") and r["state"] not in ("FAULTED", "MAINTENANCE"))

    # Estimate MTTR from the worst active fault code
    mttr_estimate = None
    for r in faulted:
        fc = int(r["fault_code"] or 0)
        est = _MTTR_MAP.get(fc)
        if est:
            mttr_estimate = max(mttr_estimate or 0, est)

    maintenance_status = MaintenanceStatus(
        machines_healthy=healthy,
        machines_at_risk=at_risk_pm,
        machines_faulted=len(faulted),
        current_mttr_estimate_min=mttr_estimate,
    )

    # ── Logistics ─────────────────────────────────────────────────────────────
    on_track = sum(1 for o in order_rows if o["computed_status"] in ("ON_TRACK",))
    monitoring = sum(1 for o in order_rows if o["computed_status"] == "MONITORING")
    at_risk_count = sum(1 for o in order_rows if o["computed_status"] == "AT_RISK")
    delayed_count = sum(1 for o in order_rows if o["computed_status"] == "DELAYED")

    upcoming = sorted(order_rows, key=lambda o: o["due_at"])
    next_order = upcoming[0] if upcoming else None

    orders_out = [
        OrderSummary(
            id=o["id"],
            customer=o["customer"],
            quantity_ordered=o["quantity_ordered"],
            due_at=o["due_at"],
            order_value_myr=float(o["order_value_myr"] or 0),
            computed_status=o["computed_status"],
        )
        for o in order_rows
    ]

    logistics = LogisticsStatus(
        orders_on_track=on_track,
        orders_monitoring=monitoring,
        orders_at_risk=at_risk_count,
        orders_delayed=delayed_count,
        next_deadline_at=next_order["due_at"] if next_order else None,
        next_deadline_customer=next_order["customer"] if next_order else None,
        orders=orders_out,
    )

    # ── Assets list ───────────────────────────────────────────────────────────
    assets_out = [
        AssetSummaryForDashboard(
            asset=r["asset"],
            display_name=r["display_name"],
            asset_type=r["asset_type"],
            state=r["state"],
            fault_code=int(r["fault_code"] or 0),
            cost_rate_myr_hr=float(r["cost_rate_myr_hr"] or 0),
            cost_so_far_myr=float(r["cost_so_far_myr"] or 0),
            last_maint_at=r.get("last_maint_at"),
            pm_risk=r.get("pm_risk"),
        )
        for r in asset_rows
    ]

    return DashboardResponse(
        scenario=scenario,
        health=health,
        health_message=health_message,
        financial=financial,
        recommended_actions=recommended_actions,
        production=production,
        maintenance=maintenance_status,
        logistics=logistics,
        assets=assets_out,
    )
