-- Migration 006: Alert Enhancements
-- Adds recommended_action, affected_orders, and resolution_notes to the alerts table.
-- Also updates alert_rules to match actual signal names from the register map.

-- ─── 1. Extend alerts table ───────────────────────────────────────────────────

ALTER TABLE alerts
    ADD COLUMN IF NOT EXISTS recommended_action TEXT,
    ADD COLUMN IF NOT EXISTS affected_orders     TEXT[],
    ADD COLUMN IF NOT EXISTS resolution_notes    TEXT;

-- ─── 2. Fix alert_rules signal names to match actual Modbus tags ──────────────
-- The original seed used placeholder signal names. Update to match register_map.json.

DELETE FROM alert_rules;

INSERT INTO alert_rules (asset, signal, warn_low, warn_high, crit_low, crit_high) VALUES
-- Component Feeder (feeder-01)
('feeder-01', 'throughput_kg_min',  70.0,  NULL,  50.0,  NULL),  -- warn if <70, crit if <50 kg/min
('feeder-01', 'hopper_level_pct',   20.0,  NULL,  10.0,  NULL),  -- warn if <20%, crit if <10%

-- Reflow Oven (mixer-01) — thresholds from AI4I 2020 process temperature band
('mixer-01',  'temperature_c',      NULL,  78.0,  NULL,  85.0),  -- warn if >78°C, crit if >85°C
('mixer-01',  'pressure_bar',        3.5,  NULL,   2.8,  NULL),  -- warn if <3.5 bar, crit if <2.8 bar

-- AOI Transfer Conveyor (conveyor-01)
('conveyor-01','speed_m_min',       20.0,  NULL,  10.0,  NULL),  -- warn if <20 m/min, crit if <10
('conveyor-01','vibration_mm_s',    NULL,   6.0,  NULL,   9.0),  -- warn if >6.0 mm/s, crit if >9.0

-- Test & Pack Station (packer-01)
('packer-01', 'seal_temperature_c', 165.0, 195.0, 155.0, 205.0), -- dual-sided band (too low or high)
('packer-01', 'line_rate_units_min', 40.0,  NULL,  25.0,  NULL)  -- warn if <40 u/min, crit if <25
ON CONFLICT (asset, signal) DO UPDATE SET
    warn_low  = EXCLUDED.warn_low,
    warn_high = EXCLUDED.warn_high,
    crit_low  = EXCLUDED.crit_low,
    crit_high = EXCLUDED.crit_high,
    updated_at = NOW();
