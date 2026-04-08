-- Migration 007: Fix v_kpi_summary to include all columns expected by
-- kpis.py router and Grafana dashboard queries:
--   availability, quality_rate, running_minutes, fault_minutes,
--   total_readings, good_readings
-- Root cause: original view (004) only had oee_percent / fault_points / total_points.

DROP VIEW IF EXISTS v_kpi_summary CASCADE;

CREATE VIEW v_kpi_summary AS
WITH window_data AS (
  SELECT asset, signal, value, quality, state, ts
  FROM telemetry
  WHERE ts >= now() - INTERVAL '8 hours'
),
quality_summary AS (
  SELECT
    asset,
    COUNT(*)                                       AS total_points,
    COUNT(*) FILTER (WHERE quality = 'good')       AS good_points,
    COUNT(*) FILTER (WHERE state  = 'FAULTED')     AS fault_points,
    COUNT(*) FILTER (WHERE state  = 'RUNNING')     AS running_points
  FROM window_data
  GROUP BY asset
),
production AS (
  SELECT asset, MAX(value) AS total_output
  FROM window_data
  WHERE signal IN ('produced_count','batch_count','items_transferred','packed_count')
  GROUP BY asset
),
open_alerts AS (
  SELECT asset, COUNT(*) AS open_alert_count
  FROM alerts WHERE state = 'OPEN'
  GROUP BY asset
)
SELECT
  am.asset,
  am.display_name,
  am.asset_type,
  am.site,
  am.line_name,

  -- availability = fraction of window the machine was RUNNING [0.0-1.0]
  CASE WHEN COALESCE(qs.total_points, 0) = 0 THEN 0.0
       ELSE ROUND((COALESCE(qs.running_points,0)::FLOAT
                   / NULLIF(qs.total_points,0))::NUMERIC, 4)
  END AS availability,

  -- quality_rate = fraction of telemetry points with quality='good' [0.0-1.0]
  CASE WHEN COALESCE(qs.total_points, 0) = 0 THEN 0.0
       ELSE ROUND((COALESCE(qs.good_points,0)::FLOAT
                   / NULLIF(qs.total_points,0))::NUMERIC, 4)
  END AS quality_rate,

  -- OEE proxy = good_points / total_points * 100 [0-100 for display]
  CASE WHEN COALESCE(qs.total_points, 0) = 0 THEN 0.0
       ELSE ROUND((COALESCE(qs.good_points,0)::FLOAT
                   / NULLIF(qs.total_points,0) * 100.0)::NUMERIC, 1)
  END AS oee_percent,

  -- minutes derived from 1Hz telemetry (points ≈ seconds)
  ROUND(COALESCE(qs.running_points, 0) / 60.0, 1) AS running_minutes,
  ROUND(COALESCE(qs.fault_points,   0) / 60.0, 1) AS fault_minutes,

  -- aliases used by kpis.py
  COALESCE(qs.total_points, 0) AS total_readings,
  COALESCE(qs.good_points,  0) AS good_readings,

  -- raw counts (kept for backward compat / Grafana queries)
  COALESCE(p.total_output,      0) AS total_output,
  COALESCE(qs.fault_points,     0) AS fault_points,
  COALESCE(qs.total_points,     0) AS total_points,
  COALESCE(oa.open_alert_count, 0) AS open_alert_count

FROM asset_metadata am
LEFT JOIN quality_summary qs ON qs.asset = am.asset
LEFT JOIN production       p  ON p.asset  = am.asset
LEFT JOIN open_alerts      oa ON oa.asset = am.asset
ORDER BY am.line_name, am.asset;
