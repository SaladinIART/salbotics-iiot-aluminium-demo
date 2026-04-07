# NEXUS API Reference

Base URL: `http://localhost:8000`
Full interactive docs: `http://localhost:8000/docs` (Swagger UI) · `http://localhost:8000/redoc`

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

## Assets

### `GET /api/v1/assets`

Returns all registered assets with their current live state.

**Response 200** — array of `AssetSummary`

```json
[
  {
    "asset": "feeder-01",
    "display_name": "Feeder 01",
    "asset_type": "feeder",
    "site": "demo-site",
    "line_name": "line-1",
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
  "http://localhost:8000/api/v1/assets/feeder-01/telemetry?signal=temp&limit=10"
```

**Response 200** — array of `TelemetryPoint`
```json
[
  {
    "ts": "2025-10-27T10:30:01+00:00",
    "asset": "feeder-01",
    "signal": "temp",
    "value": 72.4,
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
    "line_name": "line-1",
    "asset": "feeder-01",
    "asset_display_name": "Feeder 01",
    "signal": "temp",
    "alert_type": "threshold",
    "severity": "critical",
    "value": 96.2,
    "threshold": 95.0,
    "state": "OPEN",
    "message": "temp exceeded threshold",
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
    "asset": "feeder-01",
    "display_name": "Feeder 01",
    "asset_type": "feeder",
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
data: {"ts":"2025-10-27T10:30:01+00:00","asset":"feeder-01","signal":"temp","value":72.4,"quality":"good","state":"RUNNING"}
```

### `GET /api/v1/stream/alerts`

Pushes the 20 most recent OPEN alerts every 2 seconds.

**Frame format**
```
data: {"id":"3fa85f64-...","asset":"feeder-01","signal":"temp","alert_type":"threshold","severity":"critical","state":"OPEN","message":"temp exceeded threshold"}
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
