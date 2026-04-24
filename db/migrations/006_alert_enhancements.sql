-- Migration 006: Alert Enhancements
-- Adds recommended_action, affected_orders, and resolution_notes to the alerts table.
-- Also re-seeds alert_rules with aluminium-profile-line-1 signal names.

-- ─── 1. Extend alerts table ───────────────────────────────────────────────────

ALTER TABLE alerts
    ADD COLUMN IF NOT EXISTS recommended_action TEXT,
    ADD COLUMN IF NOT EXISTS affected_orders     TEXT[],
    ADD COLUMN IF NOT EXISTS resolution_notes    TEXT;

-- ─── 2. Re-seed alert_rules for aluminium-profile-line-1 ──────────────────────
-- Wipes the placeholder rules from 002 and inserts calibrated rules for each
-- of the 7 stations. Warn/crit bands match register_map.json so the alerting
-- service fires the same thresholds the simulator drives signals through.
--
-- Severity on downstream alerts (info/warning/critical) is determined by which
-- band is crossed. Priority labels (P1/P2/P3) live in v_aluminium_decision_board
-- because the alerts table CHECK constraint only accepts info/warning/critical.

DELETE FROM alert_rules;

INSERT INTO alert_rules (asset, signal, warn_low, warn_high, crit_low, crit_high) VALUES
-- Homogenisation Furnace (furnace-01)
-- billet_temp_c drives extrusion quality; under-temp scraps billets, over-temp risks burner trip.
('furnace-01',   'billet_temp_c',         540.0,  600.0,  520.0,  620.0),
('furnace-01',   'preheat_zone_temp_c',   520.0,  580.0,  500.0,  600.0),

-- Extrusion Press (press-01)
-- ram_force_kn is the flagship P1 signal — overload trips the press, halting the line.
('press-01',     'ram_force_kn',         1500.0, 2400.0, 1300.0, 2550.0),
('press-01',     'exit_profile_temp_c',   480.0,  530.0,  460.0,  550.0),

-- Water Quench (quench-01) — flagship QUALITY_HOLD_QUENCH evidence
-- Flow drop + exit-temp rise = T5/T6 temper at risk on in-box profiles.
('quench-01',    'quench_flow_lpm',       180.0,  260.0,  150.0,  300.0),
('quench-01',    'exit_temp_c',            35.0,   80.0,   30.0,   95.0),

-- Cooling Table (cooling-01)
('cooling-01',   'table_temp_c',           40.0,   85.0,   30.0,   95.0),
('cooling-01',   'conveyor_speed_m_min',    4.0,   12.0,    3.0,   14.0),

-- Profile Stretcher (stretcher-01)
-- stretch_pct controls straightness — out-of-band profiles scrap at saw inspection.
('stretcher-01', 'stretch_force_kn',      120.0,  240.0,  100.0,  260.0),
('stretcher-01', 'stretch_pct',             0.8,    2.2,    0.5,    2.6),

-- Finish Saw (saw-01)
-- cut_length_dev_mm is a two-sided band centred on 0; blade_rpm monitors wear.
('saw-01',       'blade_rpm',            2400.0, 3200.0, 2200.0, 3400.0),
('saw-01',       'cut_length_dev_mm',      -5.0,    5.0,   -8.0,    8.0),

-- Ageing Oven (ageing-01)
-- oven_temp_c and oven_dwell_min together define T6 temper; deviation holds the batch.
('ageing-01',    'oven_temp_c',           170.0,  195.0,  165.0,  205.0),
('ageing-01',    'oven_dwell_min',        460.0,  500.0,  440.0,  520.0)
ON CONFLICT (asset, signal) DO UPDATE SET
    warn_low  = EXCLUDED.warn_low,
    warn_high = EXCLUDED.warn_high,
    crit_low  = EXCLUDED.crit_low,
    crit_high = EXCLUDED.crit_high,
    updated_at = NOW();
