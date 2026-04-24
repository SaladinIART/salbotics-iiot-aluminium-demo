-- Migration 005: Business Context — Aluminium Profile Line 1
-- Adds production orders, cost config, maintenance history, and business-impact views
-- for the aluminium extrusion demo. Customer names are sanitized archetypes.

-- ─── 1. Site display name ────────────────────────────────────────────────────

UPDATE sites
SET display_name = 'Penang Plant 1 — Aluminium Profile Line 1'
WHERE site_id = 'demo-site';

-- ─── 2. production_orders ─────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS production_orders (
    id               TEXT        PRIMARY KEY,
    customer         TEXT        NOT NULL,
    product          TEXT        NOT NULL,
    quantity_ordered  INTEGER     NOT NULL,
    quantity_produced INTEGER     NOT NULL DEFAULT 0,
    due_at           TIMESTAMPTZ NOT NULL,
    status           TEXT        NOT NULL DEFAULT 'ON_TRACK'
                     CHECK (status IN ('ON_TRACK','AT_RISK','DELAYED','FULFILLED')),
    unit_revenue_myr NUMERIC(10,2) NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO production_orders (id, customer, product, quantity_ordered, due_at, status, unit_revenue_myr) VALUES
    ('PO-AL-2024-0018', 'MNC Customer A',             '6063-T6 Heatsink Profile 120mm',         2000, NOW() + INTERVAL '2 days',   'ON_TRACK', 42.00),
    ('PO-AL-2024-0021', 'Automotive Customer B',      '6082-T6 Bumper Reinforcement 1800mm',     800, NOW() + INTERVAL '28 hours', 'ON_TRACK', 95.00),
    ('PO-AL-2024-0025', 'Building Systems Customer C','6063-T5 Window Frame Mullion 2400mm',    1500, NOW() + INTERVAL '5 days',   'ON_TRACK', 58.00)
ON CONFLICT (id) DO NOTHING;

-- ─── 3. cost_config ──────────────────────────────────────────────────────────
-- cost_idle_myr_hr  : cost when machine is IDLE/STARTUP (labour + overhead, no production)
-- cost_fault_myr_hr : cost when machine is FAULTED/MAINTENANCE (idle cost + opportunity loss)

CREATE TABLE IF NOT EXISTS cost_config (
    asset              TEXT        PRIMARY KEY,
    cost_idle_myr_hr   NUMERIC(8,2) NOT NULL,
    cost_fault_myr_hr  NUMERIC(8,2) NOT NULL,
    note               TEXT
);

INSERT INTO cost_config (asset, cost_idle_myr_hr, cost_fault_myr_hr, note) VALUES
    ('furnace-01',   140.00, 280.00, 'Homogenisation furnace — high energy, long preheat if cold'),
    ('press-01',     220.00, 440.00, 'Extrusion press — line bottleneck, highest criticality'),
    ('quench-01',    130.00, 260.00, 'Water quench — T5/T6 temper gatekeeper, quality-critical'),
    ('cooling-01',   100.00, 200.00, 'Cooling table — WIP staging, backs up finishing cell'),
    ('stretcher-01', 120.00, 240.00, 'Stretcher — corrects bow/twist, required before saw'),
    ('saw-01',       100.00, 200.00, 'Cut-to-length saw — blade wear drives dimensional drift'),
    ('ageing-01',    160.00, 320.00, 'Ageing oven — T6 temper completion, shipment gate')
ON CONFLICT (asset) DO NOTHING;

-- ─── 4. maintenance_log ───────────────────────────────────────────────────────
-- 12 months of history per station with anonymised technician initials.
-- MTBF targets: press ~5wk, saw ~4wk (blade wear), stretcher ~6wk, quench ~8wk,
--               furnace ~10wk, ageing ~10wk, cooling ~12wk.

CREATE TABLE IF NOT EXISTS maintenance_log (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    asset         TEXT        NOT NULL,
    maint_type    TEXT        NOT NULL CHECK (maint_type IN ('SCHEDULED','UNPLANNED')),
    description   TEXT        NOT NULL,
    technician    TEXT,
    started_at    TIMESTAMPTZ NOT NULL,
    completed_at  TIMESTAMPTZ,
    cost_myr      NUMERIC(10,2),
    parts_replaced TEXT
);

INSERT INTO maintenance_log (asset, maint_type, description, technician, started_at, completed_at, cost_myr, parts_replaced) VALUES
-- furnace-01 (~10-week MTBF)
('furnace-01',   'SCHEDULED', 'Quarterly PM — thermocouple calibration, burner inspection',          'Tech-A', NOW() - INTERVAL '11 months', NOW() - INTERVAL '11 months' + INTERVAL '4 hours',   820.00, 'Thermocouple Type-K (x4)'),
('furnace-01',   'UNPLANNED', 'OVER_TEMPERATURE event — zone-2 thermocouple drift, replaced',        'Tech-B', NOW() - INTERVAL '7 months',  NOW() - INTERVAL '7 months'  + INTERVAL '2 hours',   420.00, 'Thermocouple zone-2'),
('furnace-01',   'SCHEDULED', 'Semi-annual PM — refractory lining inspection, burner nozzle clean',  'Tech-A', NOW() - INTERVAL '5 months',  NOW() - INTERVAL '5 months'  + INTERVAL '6 hours',  1150.00, 'Burner nozzle set'),
('furnace-01',   'UNPLANNED', 'Burner trip — igniter fault, recalibrated and rebedded',              'Tech-C', NOW() - INTERVAL '7 weeks',   NOW() - INTERVAL '7 weeks'   + INTERVAL '3 hours',   580.00, 'Igniter module'),

-- press-01 (~5-week MTBF — the heart of the line)
('press-01',     'UNPLANNED', 'EXTRUSION_OVERLOAD — die wear causing pressure spike, die reground',  'Tech-B', NOW() - INTERVAL '11 months', NOW() - INTERVAL '11 months' + INTERVAL '5 hours',  1800.00, 'Die set (regrind)'),
('press-01',     'SCHEDULED', 'Quarterly PM — ram seal + hydraulic filter change',                   'Tech-A', NOW() - INTERVAL '9 months',  NOW() - INTERVAL '9 months'  + INTERVAL '6 hours',  2100.00, 'Hydraulic filter, ram seal kit'),
('press-01',     'UNPLANNED', 'Billet jam — cleared, shear alignment adjusted',                      'Tech-C', NOW() - INTERVAL '8 months',  NOW() - INTERVAL '8 months'  + INTERVAL '1.5 hours', 340.00, NULL),
('press-01',     'UNPLANNED', 'EXTRUSION_OVERLOAD — die back-end taper worn out of spec',            'Tech-B', NOW() - INTERVAL '6 months',  NOW() - INTERVAL '6 months'  + INTERVAL '4 hours',  1900.00, 'Die set (new)'),
('press-01',     'SCHEDULED', 'Quarterly PM — load cell calibration, platen alignment check',        'Tech-A', NOW() - INTERVAL '4 months',  NOW() - INTERVAL '4 months'  + INTERVAL '5 hours',  1450.00, 'Load cell re-cert'),
('press-01',     'UNPLANNED', 'Ram force variance — hydraulic pressure transducer replaced',         'Tech-C', NOW() - INTERVAL '7 weeks',   NOW() - INTERVAL '7 weeks'   + INTERVAL '2 hours',   680.00, 'Pressure transducer'),
('press-01',     'UNPLANNED', 'BILLET_JAM — carrier alignment, cleared',                             'Tech-B', NOW() - INTERVAL '3 weeks',   NOW() - INTERVAL '3 weeks'   + INTERVAL '1 hour',    220.00, NULL),

-- quench-01 (~8-week MTBF — critical for T5/T6 temper)
('quench-01',    'SCHEDULED', 'Quarterly PM — spray nozzle clean, flow meter calibration',           'Tech-A', NOW() - INTERVAL '10 months', NOW() - INTERVAL '10 months' + INTERVAL '3 hours',   650.00, 'Spray nozzle set (x12)'),
('quench-01',    'UNPLANNED', 'QUENCH_FLOW_LOW — pump impeller wear, replaced',                      'Tech-B', NOW() - INTERVAL '7 months',  NOW() - INTERVAL '7 months'  + INTERVAL '4 hours',  1200.00, 'Pump impeller, mech seal'),
('quench-01',    'SCHEDULED', 'Semi-annual PM — chiller coil clean, flow distribution audit',        'Tech-A', NOW() - INTERVAL '4 months',  NOW() - INTERVAL '4 months'  + INTERVAL '5 hours',   920.00, 'Chiller coil descaling'),
('quench-01',    'UNPLANNED', 'Flow dropping — suction strainer clogged, cleaned',                   'Tech-C', NOW() - INTERVAL '5 weeks',   NOW() - INTERVAL '5 weeks'   + INTERVAL '1 hour',    180.00, NULL),

-- cooling-01 (~12-week MTBF — low event rate)
('cooling-01',   'SCHEDULED', 'Quarterly PM — fan bearing grease, conveyor chain tension',           'Tech-A', NOW() - INTERVAL '10 months', NOW() - INTERVAL '10 months' + INTERVAL '2 hours',   380.00, 'Fan bearing grease'),
('cooling-01',   'UNPLANNED', 'Air flow low — intake filter clogged, replaced',                      'Tech-C', NOW() - INTERVAL '6 months',  NOW() - INTERVAL '6 months'  + INTERVAL '1 hour',    150.00, 'Intake filter (x2)'),
('cooling-01',   'SCHEDULED', 'Semi-annual PM — fan motor inspection, conveyor roller check',        'Tech-A', NOW() - INTERVAL '3 months',  NOW() - INTERVAL '3 months'  + INTERVAL '3 hours',   520.00, 'Conveyor rollers (x3)'),

-- stretcher-01 (~6-week MTBF)
('stretcher-01', 'UNPLANNED', 'STRETCH_SLIP — grip jaw worn, replaced both ends',                    'Tech-B', NOW() - INTERVAL '10 months', NOW() - INTERVAL '10 months' + INTERVAL '3 hours',   720.00, 'Grip jaw set (x2)'),
('stretcher-01', 'SCHEDULED', 'Quarterly PM — hydraulic ram seal, load cell calibration',            'Tech-A', NOW() - INTERVAL '8 months',  NOW() - INTERVAL '8 months'  + INTERVAL '4 hours',   880.00, 'Ram seal kit'),
('stretcher-01', 'UNPLANNED', 'Grip slip on thin-wall profile, jaw insert refaced',                  'Tech-C', NOW() - INTERVAL '5 months',  NOW() - INTERVAL '5 months'  + INTERVAL '1.5 hours', 260.00, 'Jaw insert'),
('stretcher-01', 'SCHEDULED', 'Quarterly PM — alignment + lubrication',                              'Tech-A', NOW() - INTERVAL '3 months',  NOW() - INTERVAL '3 months'  + INTERVAL '3 hours',   560.00, NULL),
('stretcher-01', 'UNPLANNED', 'Grip jaw change — routine wear',                                      'Tech-B', NOW() - INTERVAL '6 weeks',   NOW() - INTERVAL '6 weeks'   + INTERVAL '2 hours',   420.00, 'Grip jaw set'),

-- saw-01 (~4-week MTBF — blade wear drives this)
('saw-01',       'UNPLANNED', 'Blade wear — cut length drift 3mm, blade changed',                    'Tech-C', NOW() - INTERVAL '11 months', NOW() - INTERVAL '11 months' + INTERVAL '1 hour',    220.00, 'TCT blade 500mm'),
('saw-01',       'SCHEDULED', 'Quarterly PM — feed belt tension, air clamp seal check',              'Tech-A', NOW() - INTERVAL '9 months',  NOW() - INTERVAL '9 months'  + INTERVAL '2 hours',   340.00, NULL),
('saw-01',       'UNPLANNED', 'Cut length deviation — length gauge encoder replaced',                'Tech-B', NOW() - INTERVAL '7 months',  NOW() - INTERVAL '7 months'  + INTERVAL '1.5 hours', 380.00, 'Length encoder'),
('saw-01',       'UNPLANNED', 'Blade change — routine wear, +1mm drift',                             'Tech-C', NOW() - INTERVAL '5 months',  NOW() - INTERVAL '5 months'  + INTERVAL '45 minutes', 210.00, 'TCT blade'),
('saw-01',       'SCHEDULED', 'Quarterly PM — full alignment + length calibration',                  'Tech-A', NOW() - INTERVAL '3 months',  NOW() - INTERVAL '3 months'  + INTERVAL '3 hours',   480.00, NULL),
('saw-01',       'UNPLANNED', 'Blade change — BLADE_WEAR fault ~4 wks after last',                   'Tech-C', NOW() - INTERVAL '4 weeks',   NOW() - INTERVAL '4 weeks'   + INTERVAL '45 minutes', 210.00, 'TCT blade'),

-- ageing-01 (~10-week MTBF)
('ageing-01',    'SCHEDULED', 'Quarterly PM — zone thermocouple cal, circulation fan inspection',    'Tech-A', NOW() - INTERVAL '10 months', NOW() - INTERVAL '10 months' + INTERVAL '4 hours',   780.00, 'Zone thermocouples (x3)'),
('ageing-01',    'UNPLANNED', 'AGE_TEMP_DEVIATION — zone-3 heater element partial failure',          'Tech-B', NOW() - INTERVAL '6 months',  NOW() - INTERVAL '6 months'  + INTERVAL '3 hours',   920.00, 'Heater element zone-3'),
('ageing-01',    'SCHEDULED', 'Semi-annual PM — full oven profile validation',                       'Tech-A', NOW() - INTERVAL '3 months',  NOW() - INTERVAL '3 months'  + INTERVAL '5 hours',  1050.00, 'Fan bearings'),
('ageing-01',    'UNPLANNED', 'Dwell time short — door seal degraded, replaced',                     'Tech-C', NOW() - INTERVAL '5 weeks',   NOW() - INTERVAL '5 weeks'   + INTERVAL '2 hours',   340.00, 'Door seal kit')
;

-- ─── 5. production_schedule ───────────────────────────────────────────────────
-- Aluminium extrusion runs slower than packaging; targets in profiles per shift.

CREATE TABLE IF NOT EXISTS production_schedule (
    shift_date   DATE NOT NULL,
    shift_name   TEXT NOT NULL,
    target_units INTEGER NOT NULL,
    actual_units INTEGER NOT NULL DEFAULT 0,
    product      TEXT NOT NULL DEFAULT 'Mixed Aluminium Profiles',
    PRIMARY KEY  (shift_date, shift_name)
);

INSERT INTO production_schedule (shift_date, shift_name, target_units, actual_units) VALUES
    (CURRENT_DATE - 2, 'Morning',    320, 312),
    (CURRENT_DATE - 2, 'Afternoon',  320, 305),
    (CURRENT_DATE - 2, 'Night',      240, 233),
    (CURRENT_DATE - 1, 'Morning',    320, 318),
    (CURRENT_DATE - 1, 'Afternoon',  320, 294),
    (CURRENT_DATE - 1, 'Night',      240, 221),
    (CURRENT_DATE,     'Morning',    320,   0),
    (CURRENT_DATE,     'Afternoon',  320,   0),
    (CURRENT_DATE,     'Night',      240,   0)
ON CONFLICT (shift_date, shift_name) DO NOTHING;

-- ─── 6. v_business_impact ────────────────────────────────────────────────────
-- Real-time cost accumulation for each faulted or idle asset.

CREATE OR REPLACE VIEW v_business_impact AS
SELECT
    a.asset,
    a.display_name,
    a.state,
    a.fault_code,
    a.last_seen,
    c.cost_idle_myr_hr,
    c.cost_fault_myr_hr,
    ROUND(
        EXTRACT(EPOCH FROM (NOW() - COALESCE(a.last_seen, NOW()))) / 3600.0, 4
    )::NUMERIC AS hours_in_state,
    ROUND(
        CASE
            WHEN a.state IN ('FAULTED', 'MAINTENANCE')
                THEN c.cost_fault_myr_hr * EXTRACT(EPOCH FROM (NOW() - COALESCE(a.last_seen, NOW()))) / 3600.0
            WHEN a.state = 'IDLE'
                THEN c.cost_idle_myr_hr * EXTRACT(EPOCH FROM (NOW() - COALESCE(a.last_seen, NOW()))) / 3600.0
            ELSE 0
        END, 2
    )::NUMERIC AS cost_so_far_myr,
    CASE
        WHEN a.state IN ('FAULTED', 'MAINTENANCE') THEN c.cost_fault_myr_hr
        WHEN a.state = 'IDLE'                       THEN c.cost_idle_myr_hr
        ELSE 0
    END AS cost_rate_myr_hr
FROM v_asset_current_state a
JOIN cost_config c ON a.asset = c.asset;

-- ─── 7. v_order_risk ─────────────────────────────────────────────────────────
-- Flags customer orders at risk when any machine is faulted.

CREATE OR REPLACE VIEW v_order_risk AS
SELECT
    o.id,
    o.customer,
    o.product,
    o.quantity_ordered,
    o.quantity_produced,
    o.due_at,
    o.unit_revenue_myr,
    ROUND((o.quantity_ordered * o.unit_revenue_myr), 2) AS order_value_myr,
    CASE
        WHEN o.status = 'FULFILLED' THEN 'FULFILLED'
        WHEN o.status = 'DELAYED'   THEN 'DELAYED'
        WHEN EXISTS (
            SELECT 1 FROM v_asset_current_state
            WHERE state IN ('FAULTED', 'MAINTENANCE')
        ) AND o.due_at < NOW() + INTERVAL '24 hours' THEN 'AT_RISK'
        WHEN EXISTS (
            SELECT 1 FROM v_asset_current_state
            WHERE state IN ('FAULTED', 'MAINTENANCE')
        ) AND o.due_at < NOW() + INTERVAL '72 hours' THEN 'MONITORING'
        ELSE 'ON_TRACK'
    END AS computed_status
FROM production_orders o
WHERE o.status NOT IN ('FULFILLED');

-- ─── 8. v_maintenance_status ─────────────────────────────────────────────────
-- Shows last maintenance date, MTBF estimate, and next PM recommendation.

CREATE OR REPLACE VIEW v_maintenance_status AS
WITH last_maint AS (
    SELECT DISTINCT ON (asset)
        asset,
        maint_type,
        description,
        started_at,
        completed_at,
        cost_myr,
        technician
    FROM maintenance_log
    ORDER BY asset, started_at DESC
),
mtbf_est AS (
    SELECT
        asset,
        COUNT(*) FILTER (WHERE maint_type = 'UNPLANNED') AS unplanned_count_12mo,
        COUNT(*) FILTER (WHERE maint_type = 'SCHEDULED') AS scheduled_count_12mo,
        CASE WHEN COUNT(*) FILTER (WHERE maint_type = 'UNPLANNED') > 0
             THEN ROUND(365.0 / NULLIF(COUNT(*) FILTER (WHERE maint_type = 'UNPLANNED'), 0), 1)
             ELSE NULL
        END AS mtbf_days_est
    FROM maintenance_log
    WHERE started_at > NOW() - INTERVAL '12 months'
    GROUP BY asset
)
SELECT
    lm.asset,
    lm.maint_type        AS last_maint_type,
    lm.description       AS last_maint_description,
    lm.started_at        AS last_maint_at,
    lm.technician        AS last_technician,
    me.unplanned_count_12mo,
    me.mtbf_days_est,
    -- Recommend next scheduled PM at 80% of estimated MTBF from last maintenance
    CASE WHEN me.mtbf_days_est IS NOT NULL
         THEN lm.started_at + (me.mtbf_days_est * 0.8 || ' days')::INTERVAL
         ELSE NULL
    END AS next_pm_recommended_at,
    -- Risk score: how overdue is the next PM?
    CASE
        WHEN me.mtbf_days_est IS NULL THEN 'UNKNOWN'
        WHEN NOW() > lm.started_at + (me.mtbf_days_est * 0.8 || ' days')::INTERVAL THEN 'HIGH'
        WHEN NOW() > lm.started_at + (me.mtbf_days_est * 0.6 || ' days')::INTERVAL THEN 'MEDIUM'
        ELSE 'LOW'
    END AS pm_risk
FROM last_maint lm
JOIN mtbf_est me ON lm.asset = me.asset;
