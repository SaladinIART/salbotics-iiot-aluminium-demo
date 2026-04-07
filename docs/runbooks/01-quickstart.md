# Runbook 01 — Quick Start (Zero to Running Stack)

**Time required:** ~15 minutes
**Prerequisites:** Docker Engine ≥ 24, Docker Compose ≥ 2.22, Git, 4 GB RAM free

---

## 1. Clone and configure

```bash
git clone https://github.com/SaladinIART/nexus-iiot-platform.git
cd nexus-iiot-platform
cp .env.example .env
```

The default `.env` values work out of the box for a local demo. You only need to change them for production.

| Variable | Default | Change for production |
|----------|---------|----------------------|
| `POSTGRES_PASSWORD` | `iiot_password_change_me` | ✅ Yes |
| `API_KEY` | `nexus-dev-key-change-me` | ✅ Yes |
| `GRAFANA_ADMIN_PASSWORD` | `change_me_now` | ✅ Yes |
| `MQTT_PASSWORD` | `demo_password` | ✅ Yes |

---

## 2. Start the stack

```bash
docker compose up --build -d
```

This starts 7 services in dependency order:

| Service | Starts after | Ready when |
|---------|-------------|-----------|
| `mosquitto` | — | Port 1883 open |
| `timescaledb` | — | Migrations applied automatically |
| `modbus_sim` | — | Port 1502 open |
| `collector` | mosquitto, modbus_sim | First MQTT publish appears in logs |
| `ingestor` | mosquitto, timescaledb | First DB write appears in logs |
| `alerting` | mosquitto, timescaledb | "alerting service started" in logs |
| `api` | timescaledb | `/health` returns `{"status":"ok"}` |
| `grafana` | timescaledb | Port 3000 responds |

Wait ~30 seconds for all services to be healthy, then:

```bash
docker compose ps
```

All services should show `running` or `healthy`.

---

## 3. Verify data is flowing

```bash
# Check telemetry is being written
docker exec iiot-timescaledb \
  psql -U iiot -d iiot -c \
  "SELECT asset, signal, value, ts FROM telemetry ORDER BY ts DESC LIMIT 5;"
```

You should see rows like:
```
    asset    |  signal   | value  |             ts
-------------+-----------+--------+----------------------------
 feeder-01   | temp      |  72.4  | 2025-10-27 10:30:01+00
 feeder-01   | rpm       | 1480.0 | 2025-10-27 10:30:01+00
 mixer-01    | pressure  |   3.2  | 2025-10-27 10:30:00+00
```

---

## 4. Open the interfaces

| Interface | URL | Credentials |
|-----------|-----|-------------|
| NEXUS Dashboard | http://localhost:8000 | API Key in Admin page |
| Swagger API Docs | http://localhost:8000/docs | — |
| Grafana | http://localhost:3000 | admin / change_me_now |

### First API call

```bash
curl -s -H "X-API-Key: nexus-dev-key-change-me" \
  http://localhost:8000/api/v1/assets | python3 -m json.tool
```

Expected: JSON array of 4 assets (feeder-01, mixer-01, conveyor-01, packer-01).

---

## 5. Trigger a test alert

Inject an out-of-bounds value directly into TimescaleDB to trigger the auto-close cycle:

```bash
docker exec iiot-timescaledb psql -U iiot -d iiot -c "
  INSERT INTO telemetry (ts, site, line_name, asset, signal, value, quality, state, fault_code, seq)
  VALUES (now(), 'demo-site', 'line-1', 'feeder-01', 'temp', 999.0, 'good', 'RUNNING', 0, 1);
"
```

Within ~2 seconds the alerting service detects the spike (Layer 1 threshold or Layer 2 statistical). Check:

```bash
docker exec iiot-timescaledb psql -U iiot -d iiot -c \
  "SELECT asset, signal, alert_type, severity, state, opened_at FROM alerts ORDER BY opened_at DESC LIMIT 3;"
```

---

## 6. Stop the stack

```bash
docker compose down          # stop, keep volumes (data preserved)
docker compose down -v       # stop and delete all volumes (clean slate)
```

---

## Troubleshooting

| Problem | Resolution |
|---------|-----------|
| `docker compose up` fails — port conflict | Check ports 1883, 5432, 3000, 8000 are free: `netstat -tulpn \| grep -E '1883\|5432\|3000\|8000'` |
| `timescaledb` keeps restarting | Delete its volume: `docker volume rm nexus-iiot-platform_timescaledb_data` |
| No telemetry in DB after 60s | `docker logs iiot-collector` — check Modbus connection errors |
| API returns 401 | Ensure `X-API-Key` header matches `API_KEY` in `.env` |
| Grafana shows "No data" | Confirm datasource is named `iiot-timescaledb` in provisioning |
