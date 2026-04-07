# NEXUS Data Model

All data lives in a single TimescaleDB (PostgreSQL 16) database named `iiot`.

Migrations are in `db/migrations/` and run automatically on `docker compose up` via the `docker-entrypoint-initdb.d` mount.

---

## Tables

### `telemetry` (hypertable)

The core time-series table. Partitioned by `ts` in 7-day chunks. Compression enabled after 7 days. Retention policy: 90 days.

| Column | Type | Description |
|--------|------|-------------|
| `ts` | `TIMESTAMPTZ NOT NULL` | Measurement timestamp (partition key) |
| `site` | `TEXT NOT NULL` | Site identifier (e.g., `demo-site`) |
| `line_name` | `TEXT NOT NULL` | Production line (e.g., `line-1`) |
| `asset` | `TEXT NOT NULL` | Asset identifier (e.g., `feeder-01`) |
| `signal` | `TEXT NOT NULL` | Signal name (e.g., `temp`, `rpm`) |
| `value` | `DOUBLE PRECISION NOT NULL` | Measured value |
| `quality` | `TEXT NOT NULL` | `good`, `bad`, `stale`, or `uncertain` |
| `state` | `TEXT NOT NULL` | Asset operational state at time of reading |
| `fault_code` | `INTEGER NOT NULL DEFAULT 0` | PLC fault code (0 = no fault) |
| `seq` | `INTEGER NOT NULL` | Monotonic sequence number from collector |

**Primary key:** `(ts, asset, signal)` — enables idempotent inserts.
**Index:** `telemetry_asset_signal_ts_idx` on `(asset, signal, ts DESC)` — optimises signal history queries.

---

### `alerts` (hypertable)

One row per alert event. Partitioned by `opened_at`.

| Column | Type | Description |
|--------|------|-------------|
| `id` | `UUID DEFAULT gen_random_uuid()` | Alert identifier |
| `opened_at` | `TIMESTAMPTZ NOT NULL` | When the alert was first detected (partition key) |
| `site` | `TEXT NOT NULL` | Site where the alert originated |
| `line_name` | `TEXT NOT NULL` | Production line |
| `asset` | `TEXT NOT NULL` | Asset that triggered the alert |
| `signal` | `TEXT NOT NULL` | Signal that triggered the alert |
| `alert_type` | `TEXT CHECK (... IN ('threshold','statistical','ml'))` | Detection layer |
| `severity` | `TEXT CHECK (... IN ('info','warning','critical'))` | Severity level |
| `value` | `DOUBLE PRECISION NOT NULL` | Signal value at time of trigger |
| `threshold` | `DOUBLE PRECISION` | Rule threshold that was crossed (null for ML/statistical) |
| `message` | `TEXT NOT NULL` | Human-readable description |
| `state` | `TEXT DEFAULT 'OPEN' CHECK (... IN ('OPEN','ACKED','CLOSED'))` | Lifecycle state |
| `acked_at` | `TIMESTAMPTZ` | When operator acknowledged (null if not acked) |
| `closed_at` | `TIMESTAMPTZ` | When alert was auto-closed or manually resolved |
| `rule_id` | `UUID REFERENCES alert_rules(id)` | Linked threshold rule (null for ML/statistical) |

**Indexes:**
- `alerts_asset_state_idx` on `(asset, state, opened_at DESC)` — power the API list endpoint
- `alerts_state_opened_idx` on `(state, opened_at DESC)` — power the open-alerts SSE stream

---

### `alert_rules`

Threshold configuration per `(asset, signal)` pair. Used by the alerting service's Layer 1 detector.

| Column | Type | Description |
|--------|------|-------------|
| `id` | `UUID PRIMARY KEY` | Rule identifier |
| `asset` | `TEXT NOT NULL` | Target asset |
| `signal` | `TEXT NOT NULL` | Target signal |
| `warn_low` | `DOUBLE PRECISION` | Warning threshold — low (null = no limit) |
| `warn_high` | `DOUBLE PRECISION` | Warning threshold — high |
| `crit_low` | `DOUBLE PRECISION` | Critical threshold — low |
| `crit_high` | `DOUBLE PRECISION` | Critical threshold — high |
| `enabled` | `BOOLEAN NOT NULL DEFAULT TRUE` | Disabled rules are silently ignored |
| `created_at` | `TIMESTAMPTZ` | Rule creation time |
| `updated_at` | `TIMESTAMPTZ` | Last modification time |

**Unique constraint:** `(asset, signal)` — one rule set per signal.

**Boundary semantics:** thresholds are **strict** (`<` and `>`). A value exactly at the boundary is not a violation.

---

### `asset_metadata`

Static reference data for registered assets.

| Column | Type | Description |
|--------|------|-------------|
| `asset` | `TEXT PRIMARY KEY` | Asset identifier |
| `display_name` | `TEXT NOT NULL` | Human-readable name for UI |
| `asset_type` | `TEXT NOT NULL` | Equipment category (e.g., `feeder`, `pump`) |
| `site` | `TEXT NOT NULL REFERENCES sites(site_id)` | Site this asset belongs to |
| `line_name` | `TEXT NOT NULL` | Production line |
| `cell_name` | `TEXT` | Manufacturing cell (optional) |

---

### `asset_status`

Latest operational state per asset. Updated by the ingestor on every telemetry insert.

| Column | Type | Description |
|--------|------|-------------|
| `asset` | `TEXT PRIMARY KEY` | Asset identifier |
| `ts` | `TIMESTAMPTZ` | Timestamp of the latest reading |
| `state` | `TEXT` | Latest operational state |
| `fault_code` | `INTEGER` | Latest fault code |
| `quality` | `TEXT` | Latest quality assessment |

---

### `sites`

Site registry. Used by multi-site dashboards and the API `/sites` endpoint.

| Column | Type | Description |
|--------|------|-------------|
| `site_id` | `TEXT PRIMARY KEY` | Short identifier (e.g., `demo-site`) |
| `display_name` | `TEXT NOT NULL` | Full name for UI |
| `location` | `TEXT NOT NULL` | Physical location |
| `timezone` | `TEXT NOT NULL DEFAULT 'Asia/Kuala_Lumpur'` | IANA timezone for display |
| `active` | `BOOLEAN NOT NULL DEFAULT TRUE` | Inactive sites are hidden from dashboards |

---

## Views

### `v_asset_current_state`

Joins `asset_metadata` + `sites` + `asset_status` + open alert count. Powering the floor overview page and `GET /api/v1/assets`.

```sql
SELECT am.asset, am.display_name, am.asset_type, am.site, am.line_name, am.cell_name,
       s.timezone,
       COALESCE(ast.state, 'UNKNOWN') AS state,
       COALESCE(ast.fault_code, 0)    AS fault_code,
       COALESCE(ast.quality, 'stale') AS quality,
       ast.ts AS last_seen,
       COUNT(al.id) FILTER (WHERE al.state = 'OPEN') AS open_alert_count
FROM asset_metadata am
LEFT JOIN sites s ON s.site_id = am.site
LEFT JOIN asset_status ast ON ast.asset = am.asset
LEFT JOIN alerts al ON al.asset = am.asset
GROUP BY ...
```

---

### `v_recent_alerts`

Last 100 alerts across all assets, newest-first. Joins `asset_metadata` for `asset_display_name`. Powering `GET /api/v1/alerts`.

---

### `v_kpi_summary`

8-hour rolling OEE-proxy metrics per asset. Uses a CTE to count readings, separate `good` quality readings, and sum `RUNNING` minutes vs `FAULT` minutes. Powering `GET /api/v1/kpis` and the Production KPIs Grafana dashboard.

**Derived metrics:**

| Metric | Formula |
|--------|---------|
| `quality_rate` | `good_readings / total_readings` |
| `availability` | `running_minutes / (running_minutes + fault_minutes)` |

---

### `site_assets`

Cross-join of `sites` and `asset_metadata`. Useful for multi-site asset listings. Not currently exposed via REST but available for Grafana queries.

---

## Useful admin queries

```sql
-- Row counts by table
SELECT 'telemetry' AS tbl, COUNT(*) FROM telemetry
UNION ALL SELECT 'alerts', COUNT(*) FROM alerts
UNION ALL SELECT 'alert_rules', COUNT(*) FROM alert_rules;

-- Storage per chunk (hypertable compression stats)
SELECT chunk_name, before_compression_total_bytes, after_compression_total_bytes
FROM chunk_compression_stats('telemetry') ORDER BY chunk_name;

-- Signals with highest alert frequency (last 24h)
SELECT asset, signal, alert_type, COUNT(*) AS cnt
FROM alerts
WHERE opened_at > now() - INTERVAL '24 hours'
GROUP BY asset, signal, alert_type
ORDER BY cnt DESC LIMIT 10;

-- Open alerts per site
SELECT site, severity, COUNT(*) AS cnt
FROM alerts WHERE state = 'OPEN'
GROUP BY site, severity ORDER BY site, severity;
```
