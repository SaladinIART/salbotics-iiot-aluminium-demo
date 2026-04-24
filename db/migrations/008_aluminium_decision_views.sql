-- Migration 008: Aluminium Decision Views
-- Depends on: 001_init.sql, 002_alerts.sql, 004_api_views.sql, 005_business_context.sql, 006_alert_enhancements.sql
--
-- Single source of truth for the decision demo. Grafana panels, the Svelte executive
-- view, and the FastAPI dashboard endpoint all read from these views so the story
-- stays consistent regardless of which UI the stakeholder is looking at.
--
-- Four views:
--   v_aluminium_line_current_state — per-station snapshot + computed line_health + line_scenario
--   v_aluminium_decision_board     — scenario→priority→owner→action mapping, filtered to live state
--   v_aluminium_quality_risk       — open quality-related alerts joined with affected orders
--   v_aluminium_business_risk      — customer-level value-at-risk rollup

-- ─── 1. Batch → order mapping (lightweight lookup) ────────────────────────────
-- Thin table: which in-flight batch is producing for which order? Used by the
-- quality-risk view to attach customer/order context to quench and ageing alerts.

CREATE TABLE IF NOT EXISTS batch_orders (
    batch_id        TEXT PRIMARY KEY,
    order_id        TEXT NOT NULL REFERENCES production_orders(id),
    station_scope   TEXT NOT NULL,       -- 'quench' | 'ageing' | 'press' (where the batch is vulnerable)
    profile_count   INTEGER NOT NULL,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status          TEXT NOT NULL DEFAULT 'IN_PROGRESS'
                    CHECK (status IN ('IN_PROGRESS','HOLD','RELEASED','SCRAPPED'))
);

INSERT INTO batch_orders (batch_id, order_id, station_scope, profile_count, started_at) VALUES
    ('BATCH-AL-241024-Q3', 'PO-AL-2024-0021', 'quench',  120, NOW() - INTERVAL '35 minutes'),   -- at-risk during QUALITY_HOLD_QUENCH
    ('BATCH-AL-241024-A2', 'PO-AL-2024-0018', 'ageing',  480, NOW() - INTERVAL '5 hours'),       -- at-risk during AGEING_OVEN_DEVIATION
    ('BATCH-AL-241024-P1', 'PO-AL-2024-0025', 'press',   600, NOW() - INTERVAL '2 hours')        -- at-risk during PRESS_* scenarios
ON CONFLICT (batch_id) DO NOTHING;

-- ─── 2. v_aluminium_line_current_state ───────────────────────────────────────
-- Per-station snapshot joined with the two latest analogs from telemetry_latest.
-- Adds computed columns: line_health (rollup), line_scenario (inferred), quench_delta_t.

CREATE OR REPLACE VIEW v_aluminium_line_current_state AS
WITH primary_signals AS (
    SELECT asset, signal, value
    FROM telemetry_latest
    WHERE signal IN (
        'billet_temp_c', 'ram_force_kn', 'quench_flow_lpm',
        'table_temp_c', 'stretch_force_kn', 'blade_rpm', 'oven_temp_c'
    )
),
secondary_signals AS (
    SELECT asset, signal, value
    FROM telemetry_latest
    WHERE signal IN (
        'preheat_zone_temp_c', 'exit_profile_temp_c', 'exit_temp_c',
        'conveyor_speed_m_min', 'stretch_pct', 'cut_length_dev_mm', 'oven_dwell_min'
    )
),
line_rollup AS (
    SELECT
        CASE
            WHEN EXISTS (SELECT 1 FROM v_asset_current_state WHERE asset = 'press-01' AND state IN ('FAULTED','MAINTENANCE'))
                THEN 'RED'
            WHEN EXISTS (SELECT 1 FROM v_asset_current_state WHERE asset = 'quench-01' AND state IN ('FAULTED','MAINTENANCE'))
                THEN 'RED'
            WHEN EXISTS (SELECT 1 FROM v_asset_current_state WHERE state = 'FAULTED')
                THEN 'AMBER'
            WHEN EXISTS (SELECT 1 FROM v_asset_current_state WHERE state IN ('MAINTENANCE','IDLE'))
                THEN 'AMBER'
            ELSE 'GREEN'
        END AS line_health,
        CASE
            WHEN EXISTS (SELECT 1 FROM v_asset_current_state WHERE asset = 'press-01' AND fault_code = 219)
                THEN 'EMERGENCY_PRESS_TRIP'
            WHEN EXISTS (SELECT 1 FROM v_asset_current_state WHERE asset = 'press-01' AND fault_code = 211)
                THEN 'PRESS_BOTTLENECK'
            WHEN EXISTS (SELECT 1 FROM v_asset_current_state WHERE asset = 'quench-01' AND fault_code = 311)
                THEN 'QUALITY_HOLD_QUENCH'
            WHEN EXISTS (SELECT 1 FROM v_asset_current_state WHERE asset = 'ageing-01' AND fault_code = 711)
                THEN 'AGEING_OVEN_DEVIATION'
            WHEN EXISTS (SELECT 1 FROM v_asset_current_state WHERE asset = 'stretcher-01' AND state = 'MAINTENANCE')
                THEN 'STRETCHER_BACKLOG'
            ELSE 'NORMAL'
        END AS line_scenario
)
SELECT
    a.asset,
    a.display_name,
    a.asset_type,
    a.state,
    a.fault_code,
    a.last_seen,
    a.open_alert_count,
    ROUND(ps.value::NUMERIC, 2) AS primary_value,
    ROUND(ss.value::NUMERIC, 2) AS secondary_value,
    lr.line_health,
    lr.line_scenario,
    -- quench_delta_t surfaces only on the quench-01 row — exit_temp vs inlet baseline 25°C
    CASE WHEN a.asset = 'quench-01'
         THEN ROUND((ss.value - 25.0)::NUMERIC, 1)
         ELSE NULL
    END AS quench_delta_t
FROM v_asset_current_state a
LEFT JOIN primary_signals   ps ON ps.asset = a.asset
LEFT JOIN secondary_signals ss ON ss.asset = a.asset
CROSS JOIN line_rollup lr
WHERE a.line_name = 'aluminium-profile-line-1'
ORDER BY
    CASE a.asset
        WHEN 'furnace-01'   THEN 1
        WHEN 'press-01'     THEN 2
        WHEN 'quench-01'    THEN 3
        WHEN 'cooling-01'   THEN 4
        WHEN 'stretcher-01' THEN 5
        WHEN 'saw-01'       THEN 6
        WHEN 'ageing-01'    THEN 7
        ELSE 99
    END;

-- ─── 3. decision_board_rules — seed data for the decision view ────────────────
-- Each row: scenario → priority → owner → action. The view below filters to only
-- rows whose scenario matches the currently-inferred line_scenario.

CREATE TABLE IF NOT EXISTS decision_board_rules (
    id              SERIAL PRIMARY KEY,
    scenario        TEXT NOT NULL,
    priority        TEXT NOT NULL CHECK (priority IN ('P1','P2','P3')),
    owner           TEXT NOT NULL,       -- 'Operator' | 'Shift Supervisor' | 'Quality' | 'Maintenance' | 'Plant Manager'
    action_text     TEXT NOT NULL,
    affected_orders TEXT[],
    evidence_signal TEXT,
    sort_key        INTEGER NOT NULL DEFAULT 100
);

DELETE FROM decision_board_rules;

INSERT INTO decision_board_rules (scenario, priority, owner, action_text, affected_orders, evidence_signal, sort_key) VALUES
-- ─── NORMAL ───────────────────────────────────────────────────────────────────
('NORMAL', 'P3', 'Shift Supervisor',
 'All systems nominal — continue planned production run. Verify next-hour schedule adherence.',
 NULL, NULL, 10),
('NORMAL', 'P3', 'Operator',
 'Log hourly quality sample on ageing-01 T6 output per SOP-Q-014.',
 NULL, 'aged_batch_count', 20),

-- ─── QUALITY_HOLD_QUENCH (flagship) ───────────────────────────────────────────
('QUALITY_HOLD_QUENCH', 'P2', 'Quality',
 'Place BATCH-AL-241024-Q3 on P2 QUALITY HOLD — quench_flow_lpm < 180 warn AND exit_temp_c > 80 warn. Automotive Customer B order PO-AL-2024-0021 at risk (T5/T6 temper re-inspection required).',
 ARRAY['PO-AL-2024-0021'], 'quench_flow_lpm', 10),
('QUALITY_HOLD_QUENCH', 'P2', 'Maintenance',
 'Dispatch to quench-01 — inspect spray nozzles and pump suction strainer. Historical failure mode: impeller wear (8-week MTBF, last replaced 7 months ago).',
 NULL, 'quench_flow_lpm', 20),
('QUALITY_HOLD_QUENCH', 'P2', 'Shift Supervisor',
 'Notify Automotive Customer B account manager of potential 4-hour delay on PO-AL-2024-0021 (800 pcs @ RM 95 = RM 76,000 at risk).',
 ARRAY['PO-AL-2024-0021'], NULL, 30),
('QUALITY_HOLD_QUENCH', 'P3', 'Operator',
 'Divert press output — route current billet to scrap bin until quench flow recovers > 200 lpm for 3 minutes.',
 NULL, 'quench_flow_lpm', 40),

-- ─── PRESS_BOTTLENECK ─────────────────────────────────────────────────────────
('PRESS_BOTTLENECK', 'P1', 'Maintenance',
 'Extrusion overload on press-01 — inspect die back-end taper (historical root cause). Estimated MTTR 120 min.',
 NULL, 'ram_force_kn', 10),
('PRESS_BOTTLENECK', 'P1', 'Shift Supervisor',
 'All 3 customer orders exposed — entire downstream is starved. Contact Plant Manager for customer-side communications.',
 ARRAY['PO-AL-2024-0018','PO-AL-2024-0021','PO-AL-2024-0025'], NULL, 20),
('PRESS_BOTTLENECK', 'P2', 'Operator',
 'Hold next billet in furnace-01 — do not advance until press_cycle_count resumes.',
 NULL, 'press_cycle_count', 30),
('PRESS_BOTTLENECK', 'P3', 'Quality',
 'Tag last 3 profiles from press as SUSPECT — overload may have introduced back-end defects.',
 NULL, NULL, 40),

-- ─── STRETCHER_BACKLOG ────────────────────────────────────────────────────────
('STRETCHER_BACKLOG', 'P2', 'Maintenance',
 'Stretcher offline (grip change). Confirm MTTR estimate 45 min; if >90 min, escalate and switch to manual spot-straightening.',
 NULL, 'stretch_pct', 10),
('STRETCHER_BACKLOG', 'P2', 'Shift Supervisor',
 'Cooling table WIP accumulating — throttle press output to 70% to avoid buffer overflow. Re-plan Building Systems Customer C order PO-AL-2024-0025 window-frame run.',
 ARRAY['PO-AL-2024-0025'], NULL, 20),
('STRETCHER_BACKLOG', 'P3', 'Operator',
 'Saw and ageing crews: staging pause. Confirm downstream clear-down and reset counts before resume.',
 NULL, NULL, 30),

-- ─── AGEING_OVEN_DEVIATION ────────────────────────────────────────────────────
('AGEING_OVEN_DEVIATION', 'P2', 'Quality',
 'Hold BATCH-AL-241024-A2 — oven_temp_c out of T6 band (170–195°C). MNC Customer A order PO-AL-2024-0018 heatsink profiles require retest before release.',
 ARRAY['PO-AL-2024-0018'], 'oven_temp_c', 10),
('AGEING_OVEN_DEVIATION', 'P2', 'Maintenance',
 'Inspect ageing-01 heater elements (zone-3 failed 6 months ago — check repeat). Verify circulation fan and door seals.',
 NULL, 'oven_temp_c', 20),
('AGEING_OVEN_DEVIATION', 'P3', 'Shift Supervisor',
 'Batch release contingent on hardness test pass. If fail, schedule re-ageing cycle (+8 hours — will push PO-AL-2024-0018 delivery).',
 ARRAY['PO-AL-2024-0018'], NULL, 30),

-- ─── EMERGENCY_PRESS_TRIP ─────────────────────────────────────────────────────
('EMERGENCY_PRESS_TRIP', 'P1', 'Plant Manager',
 'LINE DOWN — press emergency trip. Invoke Business Continuity Plan. All 3 customer orders impacted (value-at-risk > RM 250,000).',
 ARRAY['PO-AL-2024-0018','PO-AL-2024-0021','PO-AL-2024-0025'], NULL, 10),
('EMERGENCY_PRESS_TRIP', 'P1', 'Maintenance',
 'Clear emergency-stop interlock, inspect hydraulic pressure transducer, load cell, and die-clamp proximity switches before restart. Estimated MTTR 300 min.',
 NULL, 'ram_force_kn', 20),
('EMERGENCY_PRESS_TRIP', 'P1', 'Shift Supervisor',
 'Notify all 3 customers. Draft customer-facing incident note. Prepare overtime shift plan for recovery run.',
 ARRAY['PO-AL-2024-0018','PO-AL-2024-0021','PO-AL-2024-0025'], NULL, 30),
('EMERGENCY_PRESS_TRIP', 'P2', 'Quality',
 'Quarantine last 10 profiles from press output — ram-force spike at trip event may have induced wall-thickness variance.',
 NULL, NULL, 40);

-- ─── 4. v_aluminium_decision_board ────────────────────────────────────────────
-- Returns only rows matching the currently-active scenario (as inferred from
-- live state by v_aluminium_line_current_state). Grafana + FastAPI both read this.

CREATE OR REPLACE VIEW v_aluminium_decision_board AS
SELECT
    d.scenario,
    d.priority,
    d.owner,
    d.action_text,
    d.affected_orders,
    d.evidence_signal,
    d.sort_key
FROM decision_board_rules d
WHERE d.scenario = (SELECT DISTINCT line_scenario FROM v_aluminium_line_current_state LIMIT 1)
ORDER BY
    CASE d.priority WHEN 'P1' THEN 1 WHEN 'P2' THEN 2 WHEN 'P3' THEN 3 ELSE 9 END,
    d.sort_key;

-- ─── 5. v_aluminium_quality_risk ─────────────────────────────────────────────
-- Joins open quality-relevant alerts (quench/ageing) with the batch_orders mapping
-- so the UI can show "which batch, which customer, how much value is on the line".

CREATE OR REPLACE VIEW v_aluminium_quality_risk AS
SELECT
    b.batch_id,
    b.station_scope,
    b.profile_count,
    o.id              AS order_id,
    o.customer,
    o.product,
    b.status          AS batch_status,
    al.asset,
    al.signal         AS evidence_signal,
    al.severity,
    al.value          AS evidence_value,
    al.opened_at,
    CASE
        WHEN al.asset = 'quench-01' AND al.signal = 'quench_flow_lpm'
            THEN 'Quench flow below 180 lpm — T5/T6 temper at risk'
        WHEN al.asset = 'quench-01' AND al.signal = 'exit_temp_c'
            THEN 'Quench exit temperature above 80°C — temper retest required'
        WHEN al.asset = 'ageing-01' AND al.signal = 'oven_temp_c'
            THEN 'Ageing oven out of T6 band — hardness test required before release'
        WHEN al.asset = 'ageing-01' AND al.signal = 'oven_dwell_min'
            THEN 'Ageing dwell short of spec — under-aged profiles'
        WHEN al.asset = 'press-01'  AND al.signal = 'ram_force_kn'
            THEN 'Press overload event — wall-thickness variance possible'
        ELSE 'Process deviation — review required'
    END               AS risk_reason,
    ROUND((b.profile_count * o.unit_revenue_myr)::NUMERIC, 2) AS value_at_risk_myr
FROM batch_orders b
JOIN production_orders o  ON o.id = b.order_id
JOIN alerts al            ON al.asset IN (
    CASE b.station_scope
        WHEN 'quench' THEN 'quench-01'
        WHEN 'ageing' THEN 'ageing-01'
        WHEN 'press'  THEN 'press-01'
    END
)
WHERE al.state = 'OPEN'
  AND b.status IN ('IN_PROGRESS','HOLD')
ORDER BY
    CASE al.severity WHEN 'critical' THEN 1 WHEN 'warning' THEN 2 ELSE 3 END,
    al.opened_at DESC;

-- ─── 6. v_aluminium_business_risk ────────────────────────────────────────────
-- Customer-level rollup: total value-at-risk + cost-so-far from line downtime.
-- This feeds the "Plant Manager view" panel.

CREATE OR REPLACE VIEW v_aluminium_business_risk AS
WITH order_risk AS (
    SELECT
        customer,
        COUNT(*)                            AS orders_at_risk,
        SUM(order_value_myr)::NUMERIC(14,2) AS value_at_risk_myr
    FROM v_order_risk
    WHERE computed_status IN ('AT_RISK','DELAYED','MONITORING')
    GROUP BY customer
),
line_cost AS (
    SELECT
        SUM(cost_so_far_myr)::NUMERIC(14,2) AS cost_so_far_myr
    FROM v_business_impact
)
SELECT
    o.customer,
    o.orders_at_risk,
    o.value_at_risk_myr,
    lc.cost_so_far_myr
FROM order_risk o
CROSS JOIN line_cost lc
ORDER BY o.value_at_risk_myr DESC NULLS LAST;
