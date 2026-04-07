# Runbook 02 — Adding a New Asset

This runbook walks through registering a new physical asset (e.g., a new pump, conveyor, or compressor) so that its telemetry is collected, stored, visualised, and monitored for alerts.

**Prerequisites:** Stack is running (`docker compose up -d`).

---

## Overview of what needs to change

| Layer | What to update |
|-------|---------------|
| Modbus simulator | Add register block (dev/test only — skip for real hardware) |
| Collector | Add asset entry to `contracts/register_map.json` |
| Database | Insert row in `asset_metadata` |
| Alert rules | Insert rows in `alert_rules` |
| (Optional) Grafana | Add panel to dashboard |

---

## Step 1 — Register Modbus registers (simulator only)

If you are using the built-in `modbus_sim`, open `contracts/register_map.json` and add your asset's register block:

```json
{
  "asset": "pump-02",
  "line": "line-1",
  "unit_id": 5,
  "registers": [
    { "address": 100, "signal": "temp",     "scale": 0.1, "unit": "°C" },
    { "address": 101, "signal": "pressure",  "scale": 0.01, "unit": "bar" },
    { "address": 102, "signal": "rpm",       "scale": 1.0,  "unit": "rpm" }
  ]
}
```

For real hardware, skip this step — the collector reads from whatever IP/port/unit ID you configure.

---

## Step 2 — Insert asset metadata into TimescaleDB

```bash
docker exec iiot-timescaledb psql -U iiot -d iiot -c "
  INSERT INTO asset_metadata (asset, display_name, asset_type, site, line_name, cell_name)
  VALUES ('pump-02', 'Pump 02', 'pump', 'demo-site', 'line-1', 'cell-A')
  ON CONFLICT (asset) DO NOTHING;
"
```

Verify:
```bash
docker exec iiot-timescaledb psql -U iiot -d iiot -c \
  "SELECT asset, display_name, asset_type FROM asset_metadata;"
```

---

## Step 3 — Add alert rules

Insert threshold rules for the new asset. Adjust limits to match the equipment's operating specifications.

```bash
docker exec iiot-timescaledb psql -U iiot -d iiot -c "
  INSERT INTO alert_rules (asset, signal, warn_low, warn_high, crit_low, crit_high)
  VALUES
    ('pump-02', 'temp',     NULL,  85.0,  NULL,  95.0),
    ('pump-02', 'pressure', 0.5,   8.0,   0.2,   10.0),
    ('pump-02', 'rpm',      200.0, 1600.0, 100.0, 1800.0)
  ON CONFLICT (asset, signal) DO NOTHING;
"
```

The alerting service picks up new rules within 60 seconds (the `RuleLoader` refresh interval).

Verify:
```bash
curl -s -H "X-API-Key: nexus-dev-key-change-me" \
  "http://localhost:8000/api/v1/assets/pump-02" | python3 -m json.tool
```

---

## Step 4 — Restart the collector (if register map changed)

If you added registers to `register_map.json`:

```bash
docker compose restart collector
```

The collector re-reads the register map on startup. After ~5 seconds, check:

```bash
docker logs iiot-collector --tail=20
```

Look for lines like:
```
{"event": {"asset": "pump-02", "signal": "temp", "value": 72.1, ...}}
```

---

## Step 5 — Verify end-to-end

```bash
# Telemetry is flowing
docker exec iiot-timescaledb psql -U iiot -d iiot -c \
  "SELECT asset, signal, value, ts FROM telemetry WHERE asset = 'pump-02' ORDER BY ts DESC LIMIT 5;"

# Asset appears in API
curl -s -H "X-API-Key: nexus-dev-key-change-me" \
  http://localhost:8000/api/v1/assets | python3 -m json.tool | grep pump-02

# Alert rules loaded
docker logs iiot-alerting | grep pump-02
```

---

## Step 6 — (Optional) Add a Grafana panel

1. Open Grafana at `http://localhost:3000`
2. Open the **Floor Overview** dashboard → Edit
3. Duplicate an existing time-series panel
4. Change the SQL query — replace the `asset = 'feeder-01'` filter with `asset = 'pump-02'`
5. Save the dashboard

---

## Removing an asset

To decommission an asset without deleting its history:

```bash
# Disable alert rules (stops new alerts, preserves history)
docker exec iiot-timescaledb psql -U iiot -d iiot -c \
  "UPDATE alert_rules SET enabled = FALSE WHERE asset = 'pump-02';"

# Optionally mark inactive in metadata (API will still return it but state = UNKNOWN)
# There is no hard-delete — TimescaleDB compression preserves historical data
```
