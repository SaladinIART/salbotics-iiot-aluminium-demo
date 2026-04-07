-- Migration 004: Optimised views for the REST API
-- Phase 1 implementation — fill in during Phase 1 build
-- Depends on: 001_init.sql, 002_alerts.sql, 003_site_config.sql

-- ─── PLACEHOLDER ─────────────────────────────────────────────────────────────
-- This file is a stub created in Phase 0.
-- Full implementation is in Phase 1.
-- ─────────────────────────────────────────────────────────────────────────────

-- TODO Phase 1:
--   CREATE VIEW v_asset_current_state AS (latest telemetry + open alert count per asset)
--   CREATE VIEW v_recent_alerts AS (last 100 alerts joined to asset display names)
--   CREATE VIEW v_kpi_summary AS (OEE, throughput per asset per configurable shift window)
