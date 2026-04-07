# ADR-003 — Three-Layer Alert Architecture

**Date:** 2026-04-07
**Status:** Accepted

---

## Context

NEXUS must detect and route anomalous sensor behaviour. The naive approach — a single threshold rule per sensor — is insufficient for a production system because:
- Thresholds are set based on known failure modes. Unknown degradation patterns (slow drift, multi-signal correlation) are missed.
- Hard thresholds produce alert fatigue when a sensor naturally varies around the limit.
- Plant engineers want to know *why* an alert fired, not just *that* it fired. "ML model detected anomaly" is not actionable on its own.

The opposite extreme — a pure ML approach — fails because:
- Models require training data. At startup, there is no history.
- A model that fires without a threshold explanation gives operators nothing to act on.
- ML models can be gamed or miscalibrated. Hard limits provide a safety floor.

---

## Decision

We implement a **three-layer detection pipeline** where all three layers run in parallel on every telemetry message:

```
Layer 1: Threshold rules  →  fast, deterministic, operator-configured
Layer 2: Statistical baseline  →  automatic, detects drift without manual configuration
Layer 3: ML anomaly (IsolationForest)  →  detects subtle multi-sample patterns
```

Each layer produces typed alert objects pushed to a shared `asyncio.Queue`. The router consumes from this queue and applies deduplication, persistence, and routing.

---

## Layer Design

**Layer 1 — Threshold rules**
- Compares each incoming value against `warn_low`, `warn_high`, `crit_low`, `crit_high` from the `alert_rules` database table.
- `RuleLoader` polls the table every 60 seconds, so operators can update thresholds without restarting the service.
- Produces a `ThresholdAlert` with severity (warning/critical) and the exact threshold that was crossed.
- This is the "safety floor" — it will always fire on known dangerous conditions regardless of model state.

**Layer 2 — Statistical baseline**
- Maintains a rolling window (default: 100 samples) per `(asset, signal)` pair.
- Computes mean and standard deviation of the window.
- Fires if `|value - mean| / stddev > STAT_ZSCORE_THRESHOLD` (default: 3.0σ).
- Requires no operator configuration. Automatically adapts to the sensor's typical operating range.
- Will detect slow drift that a threshold rule would miss (e.g., temperature creeping up over 2 hours to a level that is not yet above the threshold).

**Layer 3 — ML anomaly (IsolationForest)**
- Uses `sklearn.ensemble.IsolationForest` per `(asset, signal)`.
- Cold-start guard: does not score until `ML_MIN_SAMPLES` samples have been collected (default: 50).
- Refits the model every `ML_REFIT_EVERY` samples (default: 500) to track seasonal changes.
- Fires if the anomaly score is below `ML_ANOMALY_THRESHOLD` (default: -0.1).
- This layer catches patterns that have no obvious threshold explanation — e.g., a value that is individually normal but anomalous in the context of recent history.

---

## Alert Router

The router is responsible for:
1. **Deduplication** — suppresses repeat `(asset, signal, alert_type)` combinations within a configurable window (default: 5 minutes) to prevent alert fatigue.
2. **Persistence** — writes to the `alerts` table with state `OPEN`.
3. **MQTT publish** — publishes alert event to `iiot/v1/alerts/{site}/{line}/{asset}/{alert_id}` for downstream subscribers (SCADA, notification services).
4. **Webhook** — if `ALERT_WEBHOOK_URL` is set, POSTs a JSON payload compatible with Microsoft Teams and Slack webhook format.
5. **Auto-close** — monitors whether the alerting condition has resolved and transitions `alerts.state` to `CLOSED` automatically.

---

## Alert State Machine

```
                ┌──────────────────────────────────────┐
  Condition     │                                      │
  detected ───► │  OPEN  ──── acknowledged ────► ACKED │
                │    │                              │   │
                │    └─── condition resolved ──────►│   │
                │                    │              │   │
                │                    ▼              ▼   │
                │                  CLOSED ◄─────────    │
                └──────────────────────────────────────┘
```

---

## Consequences

- The alerting service is stateful (holds rolling windows and ML models in memory). If it restarts, windows reset. This is acceptable — the window repopulates within minutes of startup.
- IsolationForest is not a real-time model in the sense of updating per sample. The refit interval means it lags behind rapid environmental changes. This is intentional — too-frequent refits would cause the model to treat an ongoing fault as "normal".
- Three simultaneous alert types for the same condition can produce three records in the `alerts` table. Deduplication is keyed by `(asset, signal, alert_type)`, not just `(asset, signal)`. This is by design — the type provides diagnostic context to the operator.

---

## Rejected Alternatives

**Grafana alerting only** — adequate for basic thresholds, but no programmatic control, no deduplication logic, no ML layer, and no MQTT event publication for downstream consumers.

**Single ML model only** — no cold-start protection, no operator-interpretable threshold explanation, no safety floor.

**External alerting service (PagerDuty, Opsgenie)** — introduces cloud dependency and SaaS cost. The webhook output of the router provides integration-ready JSON that any external service can consume, without requiring a live cloud connection for core operation.
