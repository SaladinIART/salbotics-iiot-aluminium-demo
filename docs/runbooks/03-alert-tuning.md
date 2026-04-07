# Runbook 03 — Alert Tuning

## The three detection layers

The alerting service runs three independent detection layers in priority order. Each layer produces at most one alert per `(asset, signal)` per deduplication window (default 5 minutes).

```
Layer 1: Threshold   — fires immediately when value crosses a configured limit
Layer 2: Statistical — fires when z-score > N×σ (default 3.0σ) over rolling window
Layer 3: ML          — fires when IsolationForest anomaly score < threshold (default -0.1)
```

If Layer 1 fires, Layers 2 and 3 are skipped for that message. This prevents duplicate alerts for the same condition.

---

## Tuning Layer 1 — Threshold rules

Threshold rules are stored in the `alert_rules` table. Changes take effect within 60 seconds.

### View current rules

```bash
docker exec iiot-timescaledb psql -U iiot -d iiot -c \
  "SELECT asset, signal, warn_low, warn_high, crit_low, crit_high, enabled FROM alert_rules ORDER BY asset, signal;"
```

### Update a limit

```bash
# Raise the temp warning threshold for feeder-01
docker exec iiot-timescaledb psql -U iiot -d iiot -c \
  "UPDATE alert_rules SET warn_high = 90.0 WHERE asset = 'feeder-01' AND signal = 'temp';"
```

### Disable a rule without deleting it

```bash
docker exec iiot-timescaledb psql -U iiot -d iiot -c \
  "UPDATE alert_rules SET enabled = FALSE WHERE asset = 'feeder-01' AND signal = 'rpm';"
```

### Threshold boundary behaviour

Boundaries are **strict** — a value exactly at the threshold does **not** trigger:
- `warn_high = 80.0` → value `80.0` is fine, `80.01` fires warning
- `crit_low = 5.0`   → value `5.0` is fine, `4.99` fires critical

Critical takes priority over warning — if a value crosses both `warn_high` and `crit_high`, only the `critical` alert fires.

---

## Tuning Layer 2 — Statistical (z-score)

Statistical detection catches anomalies that don't have defined limits — e.g., an RPM that's unusual for this time of day even if still within spec.

### Key parameters (set in `.env` or `docker-compose.yml`)

| Variable | Default | Effect |
|----------|---------|--------|
| `STAT_ZSCORE_THRESHOLD` | `3.0` | Sensitivity. Lower = more alerts. 2.0 is aggressive, 4.0 is conservative. |
| `STAT_WINDOW_SIZE` | `100` | Rolling window size in samples. Larger = more stable baseline. |

### Adjust sensitivity

```yaml
# docker-compose.yml — alerting service environment
environment:
  STAT_ZSCORE_THRESHOLD: "3.5"   # less sensitive
  STAT_WINDOW_SIZE: "150"        # wider baseline window
```

Then restart:
```bash
docker compose restart alerting
```

### When Layer 2 does NOT fire

- Fewer than 10 samples have been collected for this `(asset, signal)` pair since startup
- The rolling standard deviation is near zero (signal is perfectly flat — likely a stuck sensor)
- Layer 1 already fired for the same message

---

## Tuning Layer 3 — ML (IsolationForest)

Layer 3 detects multi-dimensional behavioural anomalies without requiring labelled data. It's designed for slow-developing faults that don't cross thresholds.

### Key parameters

| Variable | Default | Effect |
|----------|---------|--------|
| `ML_MIN_SAMPLES` | `50` | Samples before the model is ready. Lower = faster cold start, less accurate. |
| `ML_REFIT_EVERY` | `500` | How often the model is retrained. Lower = adapts faster, more CPU. |
| `ML_ANOMALY_THRESHOLD` | `-0.1` | Score threshold. More negative = less sensitive (fewer alerts). |

### Check if ML model is ready

```bash
docker logs iiot-alerting | grep "ml" | tail -20
```

Look for lines containing `"alert_type": "ml"` to confirm the model is scoring.

### Disable ML alerts (if too noisy during commissioning)

Set an extreme threshold that will never be reached:
```yaml
environment:
  ML_ANOMALY_THRESHOLD: "-999"
```

Re-enable once the model has had time to learn normal operating behaviour (typically after 500+ samples per signal).

---

## Managing the deduplication window

The dedup window prevents alert fatigue during sustained fault conditions — only the first alert in the window is actionable.

```yaml
environment:
  ALERT_DEDUP_WINDOW_SEC: "300"   # 5 minutes (default)
```

To shorten for testing:
```yaml
  ALERT_DEDUP_WINDOW_SEC: "10"
```

**Note:** Closing an alert (via `auto_close` or the API) clears the dedup entry, so the alert can re-fire immediately if the fault condition returns.

---

## Alert auto-close behaviour

| Alert type | Auto-close condition |
|-----------|---------------------|
| `threshold` | Latest telemetry value is back within all rule bounds |
| `statistical` | 10 minutes have elapsed since `opened_at` |
| `ml` | 10 minutes have elapsed since `opened_at` |

Auto-close runs every 60 seconds. To force an immediate check:
```bash
docker compose restart alerting
```

---

## Acknowledging alerts via API

```bash
curl -s -X POST \
  -H "X-API-Key: nexus-dev-key-change-me" \
  -H "Content-Type: application/json" \
  -d '{}' \
  "http://localhost:8000/api/v1/alerts/<alert-id>/acknowledge"
```

State transitions:
```
OPEN → ACKED (via acknowledge endpoint)
OPEN → CLOSED (via auto-close)
ACKED → CLOSED (via auto-close)
```

Closed alerts are permanent — they cannot be re-opened.
