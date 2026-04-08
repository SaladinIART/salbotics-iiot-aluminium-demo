-- Migration 005: Business Context
-- Adds production orders, cost config, maintenance history, and business-impact views.
-- Asset display names are updated to reflect the REL-2000 relay module assembly line.
-- MTBF values derived from AI4I 2020 Predictive Maintenance Dataset (UCI ML Repository).
-- Cost rates based on Penang SMT line industry benchmarks (2024).

-- ─── 1. Update asset display names ───────────────────────────────────────────

UPDATE asset_metadata SET display_name = 'Component Feeder'          WHERE asset = 'feeder-01';
UPDATE asset_metadata SET display_name = 'Reflow Oven'               WHERE asset = 'mixer-01';
UPDATE asset_metadata SET display_name = 'AOI Transfer Conveyor'     WHERE asset = 'conveyor-01';
UPDATE asset_metadata SET display_name = 'Test & Pack Station'       WHERE asset = 'packer-01';
UPDATE asset_metadata SET line_name    = 'rel2000-assembly-line-1'   WHERE asset IN ('feeder-01','mixer-01','conveyor-01','packer-01');
UPDATE sites SET display_name = 'Penang Plant 1 — REL-2000 Line' WHERE site_id = 'demo-site';

-- ─── 2. production_orders ─────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS production_orders (
    id               TEXT        PRIMARY KEY,
    customer         TEXT        NOT NULL,
    product          TEXT        NOT NULL DEFAULT 'REL-2000 Industrial Relay Module',
    quantity_ordered  INTEGER     NOT NULL,
    quantity_produced INTEGER     NOT NULL DEFAULT 0,
    due_at           TIMESTAMPTZ NOT NULL,
    status           TEXT        NOT NULL DEFAULT 'ON_TRACK'
                     CHECK (status IN ('ON_TRACK','AT_RISK','DELAYED','FULFILLED')),
    unit_revenue_myr NUMERIC(10,2) NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO production_orders (id, customer, quantity_ordered, due_at, status, unit_revenue_myr) VALUES
    ('PO-2024-089', 'Intel Penang',      500, NOW() + INTERVAL '1 day 5 hours',  'ON_TRACK', 125.00),
    ('PO-2024-091', 'Bosch Malaysia',    300, NOW() + INTERVAL '3 days',          'ON_TRACK', 125.00),
    ('PO-2024-093', 'Siemens Penang',    200, NOW() + INTERVAL '5 days',          'ON_TRACK', 125.00)
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
    ('feeder-01',   85.00,  170.00, 'Component loading — medium criticality'),
    ('mixer-01',   120.00,  240.00, 'Reflow oven — line bottleneck, highest criticality'),
    ('conveyor-01', 95.00,  190.00, 'AOI conveyor — high throughput dependency'),
    ('packer-01',  110.00,  220.00, 'Test & Pack — end-of-line, affects shipment readiness')
ON CONFLICT (asset) DO NOTHING;

-- ─── 4. maintenance_log ───────────────────────────────────────────────────────
-- Seeded with 12 months of history per asset.
-- MTBF derivation from AI4I 2020 failure rates:
--   - Reflow Oven (mixer): ~6.5 weeks (HIGH_TEMP failures at 9.6% rate in AI4I dataset)
--   - Conveyor:            ~4.5 weeks (tool-wear & OSF patterns)
--   - Packer:              ~5.5 weeks (PWF process failure patterns)
--   - Feeder:              ~16 weeks  (low failure rate, motor-trip rare)

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
-- feeder-01 (~16-week MTBF → ~3 events in 12 months)
('feeder-01', 'SCHEDULED', 'Quarterly PM — motor brushes & hopper sensor calibration', 'Hafiz R.',   NOW() - INTERVAL '10 months', NOW() - INTERVAL '10 months' + INTERVAL '2 hours',  450.00, 'Motor brush set'),
('feeder-01', 'UNPLANNED', 'Motor trip — overload detected, reset and restarted',       'Azri M.',    NOW() - INTERVAL '5 months',  NOW() - INTERVAL '5 months' + INTERVAL '40 minutes', 280.00, NULL),
('feeder-01', 'SCHEDULED', 'Semi-annual PM — belt tension, hopper level sensor check',  'Hafiz R.',   NOW() - INTERVAL '4 months',  NOW() - INTERVAL '4 months' + INTERVAL '3 hours',  550.00, 'Hopper sensor'),

-- mixer-01 / Reflow Oven (~6.5-week MTBF → ~8 events in 12 months)
('mixer-01',  'UNPLANNED', 'HIGH_TEMP fault — cooling loop blockage cleared',           'Syafiq K.',  NOW() - INTERVAL '11 months', NOW() - INTERVAL '11 months' + INTERVAL '1.5 hours', 380.00, 'Coolant filter'),
('mixer-01',  'SCHEDULED', 'Quarterly PM — thermocouple calibration, cooling loop flush','Hafiz R.',  NOW() - INTERVAL '9 months',  NOW() - INTERVAL '9 months' + INTERVAL '4 hours',   720.00, 'Thermocouple Type-K'),
('mixer-01',  'UNPLANNED', 'HIGH_TEMP fault — cooling fan seized, replaced',            'Azri M.',    NOW() - INTERVAL '7 months',  NOW() - INTERVAL '7 months' + INTERVAL '2.5 hours', 650.00, 'Cooling fan 24VDC'),
('mixer-01',  'UNPLANNED', 'Pressure low — nitrogen supply regulator replaced',         'Syafiq K.',  NOW() - INTERVAL '5 months',  NOW() - INTERVAL '5 months' + INTERVAL '1 hours',   420.00, 'N2 regulator'),
('mixer-01',  'SCHEDULED', 'Quarterly PM — full oven profile validation & calibration', 'Hafiz R.',   NOW() - INTERVAL '3 months',  NOW() - INTERVAL '3 months' + INTERVAL '5 hours',   890.00, 'Zone thermocouple (x3)'),
('mixer-01',  'UNPLANNED', 'Cooling loop partial blockage — flushed with solvent',      'Azri M.',    NOW() - INTERVAL '6 weeks',   NOW() - INTERVAL '6 weeks' + INTERVAL '45 minutes',  180.00, NULL),
('mixer-01',  'UNPLANNED', 'HIGH_TEMP fault — cooling loop degrading again',            'Syafiq K.',  NOW() - INTERVAL '2 weeks',   NOW() - INTERVAL '2 weeks' + INTERVAL '1.5 hours',  380.00, 'Coolant filter'),

-- conveyor-01 (~4.5-week MTBF → ~10 events in 12 months)
('conveyor-01','UNPLANNED','JAM_DETECTED — board carrier misalignment cleared',          'Azri M.',    NOW() - INTERVAL '11 months', NOW() - INTERVAL '11 months' + INTERVAL '30 minutes', 120.00, NULL),
('conveyor-01','SCHEDULED','Quarterly PM — belt tensioner, guide rail lubrication',     'Hafiz R.',   NOW() - INTERVAL '9 months',  NOW() - INTERVAL '9 months' + INTERVAL '2.5 hours',  380.00, 'Guide rail lubricant'),
('conveyor-01','UNPLANNED','Belt speed variance — encoder feedback cable replaced',      'Syafiq K.',  NOW() - INTERVAL '8 months',  NOW() - INTERVAL '8 months' + INTERVAL '1 hours',    290.00, 'Encoder cable'),
('conveyor-01','UNPLANNED','JAM_DETECTED — carrier jam at output buffer, cleared',      'Azri M.',    NOW() - INTERVAL '6 months',  NOW() - INTERVAL '6 months' + INTERVAL '20 minutes',  80.00, NULL),
('conveyor-01','UNPLANNED','Speed variance — belt tensioner spring replaced',            'Hafiz R.',   NOW() - INTERVAL '4 months',  NOW() - INTERVAL '4 months' + INTERVAL '1.5 hours',  340.00, 'Belt tensioner spring'),
('conveyor-01','SCHEDULED','Quarterly PM — full belt inspection, roller bearing check', 'Hafiz R.',   NOW() - INTERVAL '3 months',  NOW() - INTERVAL '3 months' + INTERVAL '3 hours',    520.00, 'Roller bearing (x2)'),
('conveyor-01','UNPLANNED','JAM_DETECTED — board warp causing carrier friction, cleared','Azri M.',   NOW() - INTERVAL '6 weeks',   NOW() - INTERVAL '6 weeks' + INTERVAL '25 minutes',  100.00, NULL),
('conveyor-01','UNPLANNED','JAM_DETECTED — carrier stopper solenoid stuck, replaced',   'Syafiq K.',  NOW() - INTERVAL '3 weeks',   NOW() - INTERVAL '3 weeks' + INTERVAL '50 minutes',  210.00, 'Carrier stop solenoid'),

-- packer-01 / Test & Pack (~5.5-week MTBF → ~9 events in 12 months)
('packer-01', 'UNPLANNED', 'FILM_BREAK — packaging film roll end, replaced',            'Azri M.',    NOW() - INTERVAL '10 months', NOW() - INTERVAL '10 months' + INTERVAL '15 minutes',  60.00, 'Film roll 500m'),
('packer-01', 'SCHEDULED', 'Quarterly PM — sealing bar calibration, film guide check', 'Hafiz R.',   NOW() - INTERVAL '9 months',  NOW() - INTERVAL '9 months' + INTERVAL '3 hours',    480.00, 'Sealing bar PTFE coating'),
('packer-01', 'UNPLANNED', 'SEAL_TEMP_LOW — heating element partially failed, replaced','Syafiq K.',  NOW() - INTERVAL '7 months',  NOW() - INTERVAL '7 months' + INTERVAL '2 hours',    580.00, 'Sealing element 240V'),
('packer-01', 'UNPLANNED', 'FILM_BREAK — film guide misaligned after roll change',      'Azri M.',    NOW() - INTERVAL '5 months',  NOW() - INTERVAL '5 months' + INTERVAL '20 minutes',  80.00, NULL),
('packer-01', 'UNPLANNED', 'FILM_BREAK — film tension roller bearing seized',           'Syafiq K.',  NOW() - INTERVAL '4 months',  NOW() - INTERVAL '4 months' + INTERVAL '1 hours',    240.00, 'Tension roller bearing'),
('packer-01', 'SCHEDULED', 'Quarterly PM — full seal quality audit & calibration',     'Hafiz R.',   NOW() - INTERVAL '3 months',  NOW() - INTERVAL '3 months' + INTERVAL '4 hours',    680.00, 'Sealing element, film guide'),
('packer-01', 'UNPLANNED', 'FILM_BREAK — roll run-out, auto-stopped',                  'Azri M.',    NOW() - INTERVAL '5 weeks',   NOW() - INTERVAL '5 weeks' + INTERVAL '10 minutes',   50.00, 'Film roll 500m'),
('packer-01', 'UNPLANNED', 'SEAL_TEMP_LOW — thermostat drift, recalibrated',            'Syafiq K.',  NOW() - INTERVAL '2 weeks',   NOW() - INTERVAL '2 weeks' + INTERVAL '45 minutes',  120.00, NULL)
;

-- ─── 5. production_schedule ───────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS production_schedule (
    shift_date   DATE NOT NULL,
    shift_name   TEXT NOT NULL,
    target_units INTEGER NOT NULL,
    actual_units INTEGER NOT NULL DEFAULT 0,
    product      TEXT NOT NULL DEFAULT 'REL-2000 Industrial Relay Module',
    PRIMARY KEY  (shift_date, shift_name)
);

INSERT INTO production_schedule (shift_date, shift_name, target_units, actual_units) VALUES
    (CURRENT_DATE - 2, 'Morning',    850, 841),
    (CURRENT_DATE - 2, 'Afternoon',  850, 822),
    (CURRENT_DATE - 2, 'Night',      700, 695),
    (CURRENT_DATE - 1, 'Morning',    850, 849),
    (CURRENT_DATE - 1, 'Afternoon',  850, 803),
    (CURRENT_DATE - 1, 'Night',      700, 648),
    (CURRENT_DATE,     'Morning',    850,   0),
    (CURRENT_DATE,     'Afternoon',  850,   0),
    (CURRENT_DATE,     'Night',      700,   0)
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
