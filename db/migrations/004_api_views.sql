-- Migration 004: Optimised views for the REST API
-- Depends on: 001_init.sql, 002_alerts.sql, 003_site_config.sql
-- Used by: services/api (Phase 3) — these views back the key API endpoints

-- ─── v_asset_current_state ───────────────────────────────────────────────────
-- Powers: GET /api/v1/assets  and  GET /api/v1/stream/telemetry (SSE)
--
-- Returns one row per asset with:
--   - Current machine state and fault code (from asset_status view)
--   - Timestamp of last telemetry received
--   - Count of currently OPEN alerts
--   - Asset display metadata (from asset_metadata + sites)
--
-- The SSE endpoint polls this view every 2 seconds and pushes rows whose
-- last_seen or open_alert_count has changed since the previous poll.

CREATE OR REPLACE VIEW v_asset_current_state AS
SELECT
  am.asset,
  am.display_name,
  am.asset_type,
  am.site,
  am.line_name,
  am.cell_name,
  s.timezone,
  COALESCE(ast.state,      'UNKNOWN') AS state,
  COALESCE(ast.fault_code, 0)         AS fault_code,
  COALESCE(ast.quality,    'stale')   AS quality,
  ast.ts                              AS last_seen,
  COUNT(al.id) FILTER (
    WHERE al.state = 'OPEN'
  )                                   AS open_alert_count
FROM asset_metadata am
LEFT JOIN sites        s   ON s.site_id  = am.site
LEFT JOIN asset_status ast ON ast.asset  = am.asset
LEFT JOIN alerts       al  ON al.asset   = am.asset
GROUP BY
  am.asset, am.display_name, am.asset_type,
  am.site, am.line_name, am.cell_name,
  s.timezone,
  ast.state, ast.fault_code, ast.quality, ast.ts;

-- ─── v_recent_alerts ─────────────────────────────────────────────────────────
-- Powers: GET /api/v1/alerts  and  GET /api/v1/stream/alerts (SSE)
--
-- Returns the 100 most recent alerts (any state) with asset display names
-- joined in so the frontend doesn't need a second query.
--
-- The SSE endpoint polls this view for rows with state='OPEN' and
-- opened_at > last_poll_ts, pushing new rows to connected browsers.

CREATE OR REPLACE VIEW v_recent_alerts AS
SELECT
  al.id,
  al.opened_at,
  al.site,
  al.line_name,
  al.asset,
  am.display_name  AS asset_display_name,
  al.signal,
  al.alert_type,
  al.severity,
  al.value,
  al.threshold,
  al.state,
  al.message,
  al.acked_at,
  al.closed_at,
  al.rule_id
FROM alerts al
LEFT JOIN asset_metadata am ON am.asset = al.asset
ORDER BY al.opened_at DESC
LIMIT 100;

-- ─── v_kpi_summary ───────────────────────────────────────────────────────────
-- Powers: GET /api/v1/kpis
--
-- Returns a KPI row per asset for the rolling 8-hour shift window.
-- The API can override the window by querying the base tables directly,
-- but this view covers the default dashboard use case.
--
-- OEE approximation (simplified — full ISA-95 OEE requires planned production
-- time which is out of scope for this demo):
--   Availability proxy = good_points / total_points
--   Production output  = max value of the asset's count signal
--   Fault exposure     = fault_points / total_points

CREATE OR REPLACE VIEW v_kpi_summary AS
WITH window_data AS (
  SELECT
    asset,
    signal,
    value,
    quality,
    state,
    ts
  FROM telemetry
  WHERE ts >= now() - INTERVAL '8 hours'
),
quality_summary AS (
  SELECT
    asset,
    COUNT(*)                                   AS total_points,
    COUNT(*) FILTER (WHERE quality = 'good')   AS good_points,
    COUNT(*) FILTER (WHERE state  = 'FAULTED') AS fault_points
  FROM window_data
  GROUP BY asset
),
production AS (
  SELECT
    asset,
    MAX(value) AS total_output
  FROM window_data
  WHERE signal IN ('produced_count', 'batch_count', 'items_transferred', 'packed_count')
  GROUP BY asset
),
open_alerts AS (
  SELECT
    asset,
    COUNT(*) AS open_alert_count
  FROM alerts
  WHERE state = 'OPEN'
  GROUP BY asset
)
SELECT
  am.asset,
  am.display_name,
  am.asset_type,
  am.site,
  am.line_name,
  -- OEE proxy as a percentage (0.0 – 100.0)
  CASE
    WHEN COALESCE(qs.total_points, 0) = 0 THEN 0.0
    ELSE ROUND(
      (qs.good_points::FLOAT / qs.total_points * 100.0)::NUMERIC, 1
    )
  END                                  AS oee_percent,
  COALESCE(p.total_output,       0)    AS total_output,
  COALESCE(qs.fault_points,      0)    AS fault_points,
  COALESCE(qs.total_points,      0)    AS total_points,
  COALESCE(oa.open_alert_count,  0)    AS open_alert_count
FROM asset_metadata am
LEFT JOIN quality_summary qs ON qs.asset = am.asset
LEFT JOIN production       p  ON p.asset  = am.asset
LEFT JOIN open_alerts      oa ON oa.asset = am.asset
ORDER BY am.line_name, am.asset;
