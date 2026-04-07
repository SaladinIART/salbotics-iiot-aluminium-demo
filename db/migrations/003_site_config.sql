-- Migration 003: Site configuration
-- Depends on: 001_init.sql (asset_metadata must exist)
-- Used by: services/api (Phase 3) GET /api/v1/sites

-- ─── SITES ───────────────────────────────────────────────────────────────────
-- Reference table for physical plant locations.
-- The 'site' column in telemetry and alerts matches site_id here.
-- Adding a new site = insert a row here + deploy a new collector with SITE=<site_id>.

CREATE TABLE IF NOT EXISTS sites (
  site_id      TEXT        PRIMARY KEY,
  display_name TEXT        NOT NULL,
  location     TEXT        NOT NULL,
  -- IANA timezone string (e.g. 'Asia/Kuala_Lumpur', 'Europe/Berlin')
  -- Used by the frontend to localise timestamps per site
  timezone     TEXT        NOT NULL DEFAULT 'Asia/Kuala_Lumpur',
  active       BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO sites (site_id, display_name, location, timezone)
VALUES ('demo-site', 'Demo Site (Penang)', 'Penang, Malaysia', 'Asia/Kuala_Lumpur')
ON CONFLICT (site_id) DO NOTHING;

-- ─── SITE ASSETS VIEW ────────────────────────────────────────────────────────
-- Joins site metadata to asset metadata.
-- Answers: "give me all assets and their site context in one query."
-- Used by the API's GET /api/v1/sites and the frontend SiteSelector component.

CREATE OR REPLACE VIEW site_assets AS
SELECT
  s.site_id,
  s.display_name   AS site_display_name,
  s.location,
  s.timezone,
  s.active         AS site_active,
  a.asset,
  a.line_name,
  a.cell_name,
  a.asset_type,
  a.display_name   AS asset_display_name
FROM sites s
JOIN asset_metadata a ON a.site = s.site_id
ORDER BY s.site_id, a.line_name, a.asset;
