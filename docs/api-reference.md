# NEXUS API Reference

Base URL: `http://localhost:8080`
Full interactive docs: `http://localhost:8080/docs` (Swagger UI) · `http://localhost:8080/redoc`

## Authentication

All endpoints except `/health` require the `X-API-Key` header.

```
X-API-Key: nexus-dev-key-change-me
```

On `401 Unauthorized`:
```json
{ "detail": "Invalid or missing API key" }
```

---

## Health

### `GET /health`

No authentication required.

**Response 200**
```json
{ "status": "ok" }
```

---

## Executive Demo

### `GET /api/v1/dashboard`

Returns the aluminium executive summary used by the Svelte dashboard.

### `GET /api/v1/demo/scenario`

Returns the currently active aluminium demo scenario.

### `POST /api/v1/demo/scenario/{name}`

Triggers one of the supported demo scenarios:

- `NORMAL`
- `QUALITY_HOLD_QUENCH`
- `PRESS_BOTTLENECK`
- `STRETCHER_BACKLOG`
- `AGEING_OVEN_DEVIATION`
- `EMERGENCY_PRESS_TRIP`

**Example**
```bash
curl -s -X POST \
  -H "X-API-Key: nexus-dev-key-change-me" \
  http://localhost:8080/api/v1/demo/scenario/QUALITY_HOLD_QUENCH
```

---

## Assets

### `GET /api/v1/assets`

Returns all registered assets with their current live state.

**Response 200** — array of `AssetSummary`

```json
[
  {
    "asset": "quench-01",
    "display_name": "Water Quench",
    "asset_type": "quench",
    "site": "demo-site",
    "line_name": "aluminium-profile-line-1",
    "cell_name": null,
    "state": "RUNNING",
    "fault_code": 0,
    "quality": "good",
    "last_seen": "2025-10-27T10:30:01+00:00",
    "open_alert_count": 0
  }
]
```

---

### `GET /api/v1/assets/{asset_id}`

Returns a single asset. `404` if not found.

---

### `GET /api/v1/assets/{asset_id}/status`

Returns the real-time status fields only (state, fault_code, quality, last_seen, open_alert_count).

---

### `GET /api/v1/assets/{asset_id}/telemetry`

Returns historical telemetry for one asset, newest-first.

**Query parameters**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `signal` | string | — | Filter to a specific signal name (e.g., `temp`) |
| `from` | ISO 8601 datetime | year 2000 | Start of time range |
| `to` | ISO 8601 datetime | year 2100 | End of time range |
| `limit` | integer 1–5000 | 500 | Maximum rows returned |

**Example**
```bash
curl -s -H "X-API-Key: nexus-dev-key-change-me" \
  "http://localhost:8080/api/v1/assets/quench-01/telemetry?signal=quench_flow_lpm&limit=10"
```

**Response 200** — array of `TelemetryPoint`
```json
[
  {
    "ts": "2025-10-27T10:30:01+00:00",
    "asset": "quench-01",
    "signal": "quench_flow_lpm",
    "value": 221.8,
    "quality": "good",
    "state": "RUNNING"
  }
]
```

---

## Alerts

### `GET /api/v1/alerts`

Returns recent alerts (max 100 by default), newest-first.

**Query parameters**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `state` | `OPEN` \| `ACKED` \| `CLOSED` | — | Filter by alert state |
| `asset` | string | — | Filter to a specific asset |
| `limit` | integer 1–1000 | 100 | Maximum rows returned |

**Response 200** — array of `AlertOut`
```json
[
  {
    "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "opened_at": "2025-10-27T10:31:00+00:00",
    "site": "demo-site",
    "line_name": "aluminium-profile-line-1",
    "asset": "quench-01",
    "asset_display_name": "Water Quench",
    "signal": "quench_flow_lpm",
    "alert_type": "threshold",
    "severity": "warning",
    "value": 152.1,
    "threshold": 180.0,
    "state": "OPEN",
    "message": "quench_flow_lpm 152 below warning low 180",
    "acked_at": null,
    "closed_at": null,
    "rule_id": "00000000-0000-0000-0000-000000000001"
  }
]
```

---

### `POST /api/v1/alerts/{alert_id}/acknowledge`

Moves an `OPEN` alert to `ACKED` state. Returns `404` if the alert is not found or is already `ACKED`/`CLOSED`.

**Request body** (optional)
```json
{ "note": "Checked — scheduled maintenance in 2h" }
```

**Response 200**
```json
{ "id": "3fa85f64-...", "state": "ACKED" }
```

---

## KPIs

### `GET /api/v1/kpis`

Returns an OEE-proxy KPI summary per asset over a rolling time window.

**Query parameters**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `window` | float 1–168 | 8.0 | Rolling window in hours |

**Response 200** — array of `KpiSummary`
```json
[
  {
    "asset": "press-01",
    "display_name": "Extrusion Press",
    "asset_type": "press",
    "window_hours": 8.0,
    "total_readings": 28800,
    "good_readings": 28650,
    "quality_rate": 0.9948,
    "running_minutes": 470.0,
    "fault_minutes": 10.0,
    "availability": 0.979,
    "open_alert_count": 0
  }
]
```

---

## Sites

### `GET /api/v1/sites`

Returns all registered sites.

**Response 200** — array of `SiteSummary`
```json
[
  {
    "site_id": "demo-site",
    "display_name": "Demo Site (Penang)",
    "location": "Penang, Malaysia",
    "timezone": "Asia/Kuala_Lumpur",
    "active": true
  }
]
```

---

## SSE Streams

Server-Sent Events — the browser subscribes once and receives a continuous stream of `data:` frames. Reconnects automatically every 3 seconds on failure.

### `GET /api/v1/stream/telemetry`

Pushes the 20 most recent telemetry rows every 2 seconds.

**Frame format**
```
data: {"ts":"2026-04-24T13:40:01+00:00","asset":"quench-01","signal":"quench_flow_lpm","value":221.8,"quality":"good","state":"RUNNING"}
```

### `GET /api/v1/stream/alerts`

Pushes the 20 most recent OPEN alerts every 2 seconds.

**Frame format**
```
data: {"id":"3fa85f64-...","asset":"quench-01","signal":"quench_flow_lpm","alert_type":"threshold","severity":"warning","state":"OPEN","message":"quench_flow_lpm 152 below warning low 180"}
```

**JavaScript usage**
```js
const es = new EventSource('/api/v1/stream/telemetry', {
  headers: { 'X-API-Key': 'nexus-dev-key-change-me' }
});
es.onmessage = (ev) => console.log(JSON.parse(ev.data));
```

---

## Error responses

| Status | Meaning |
|--------|---------|
| 401 | Missing or invalid `X-API-Key` |
| 404 | Resource not found |
| 422 | Request validation error (query param out of range, invalid UUID, etc.) |
| 500 | Internal server error — check `docker logs iiot-api` |
